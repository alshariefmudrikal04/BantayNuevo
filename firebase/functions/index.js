const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// Set these once with:
//   firebase functions:secrets:set PHILSMS_API_KEY
//   firebase functions:secrets:set PHILSMS_SENDER_ID
// (PhilSMS is a PH-based SMS gateway — see philsms.com. sender_id is
// alphanumeric, max 11 characters, e.g. "BantayNuevo" — exactly 11.)
const philSmsApiKey = defineSecret("PHILSMS_API_KEY");
const philSmsSenderId = defineSecret("PHILSMS_SENDER_ID");

// Set these once with:
//   firebase functions:secrets:set GMAIL_ADDRESS
//   firebase functions:secrets:set GMAIL_APP_PASSWORD
// GMAIL_APP_PASSWORD is a 16-character App Password generated from
// myaccount.google.com/apppasswords — NOT your actual Gmail password.
// Needs 2-Step Verification turned on for that Google account first,
// otherwise the App Passwords page won't be available at all.
const gmailAddress = defineSecret("GMAIL_ADDRESS");
const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");

const PIN_RECOVERY_CODE_TTL_MINUTES = 10;
const PIN_RECOVERY_MAX_ATTEMPTS = 5;

/**
 * Numbers get stored however a resident typed them (09171234567,
 * +639171234567, 639171234567, ...) — client-side normalization only
 * strips spaces/dashes, it doesn't enforce one format. PhilSMS's API
 * expects "639171234567": country code, no leading +, no leading 0. This
 * converts whatever's on file into that shape rather than assuming it's
 * already right, so a number saved in any common PH format still sends.
 */
function toPhilSmsFormat(rawNumber) {
  const digits = rawNumber.replace(/[^0-9]/g, "");
  if (digits.startsWith("63") && digits.length === 12) return digits;
  if (digits.startsWith("0") && digits.length === 11) return `63${digits.slice(1)}`;
  if (digits.startsWith("9") && digits.length === 10) return `63${digits}`;
  return digits; // best effort — logged downstream if PhilSMS rejects it
}

/**
 * Sends an SMS via the PhilSMS API. Fails silently (logs only) so one bad
 * number never blocks the rest of the notification fan-out. PhilSMS
 * accepts multiple recipients as one comma-joined string in a single
 * request (same "one message, many numbers" shape Semaphore used, just a
 * different API surface — JSON body + Bearer auth instead of form-encoded
 * + apikey field).
 */
async function sendPhilSmsMessage(apiKey, senderId, numbers, message) {
  if (!numbers || numbers.length === 0) return;
  const recipients = numbers.map(toPhilSmsFormat).join(",");
  try {
    const res = await fetch("https://dashboard.philsms.com/api/v3/sms/send", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify({
        recipient: recipients,
        sender_id: senderId,
        type: "plain",
        message,
      }),
    });
    const body = await res.json().catch(() => null);
    if (!res.ok || (body && body.status === "error")) {
      logger.error("PhilSMS send failed", {status: res.status, body});
    }
  } catch (err) {
    logger.error("PhilSMS send threw", err);
  }
}

/**
 * Fires when a resident creates an sos_alerts/{alertId} doc via the ONLINE
 * path in sos_screen.dart (AGENTS.md §5/§7). Handles:
 *   1. Push notification to tanod (+ police if escalated) — see NOTE below,
 *      this needs users/{uid}.fcmToken, which isn't written anywhere yet.
 *   2. SMS to every one of the resident's emergency_contacts — ALWAYS,
 *      regardless of escalationTarget, since contacts have no app.
 *   3. Backup SMS ping to tanod/police, in case push is delayed/missed.
 *   4. Logs which contacts were successfully texted back onto the alert doc.
 */
exports.onSosCreated = onDocumentCreated(
  {document: "sos_alerts/{alertId}", secrets: [philSmsApiKey, philSmsSenderId]},
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const alert = snap.data();

    if (!alert.location || alert.location.lat == null || alert.location.lng == null) {
      logger.warn("SOS alert missing location, skipping notify", event.params.alertId);
      return;
    }

    const residentDoc = await db.collection("users").doc(alert.residentId).get();
    const residentName = residentDoc.exists ? residentDoc.data().name : "A resident";

    const mapsLink = `https://maps.google.com/?q=${alert.location.lat},${alert.location.lng}`;
    const smsMessage = `[EMERGENCY - Bantay Nuevo] ${residentName} needs help. Location: ${mapsLink}`;

    const rolesToNotify = alert.escalationTarget === "pnp" ? ["tanod", "police"] : ["tanod"];
    const respondersSnap = await db.collection("users").where("role", "in", rolesToNotify).get();

    // 1. Push notification.
    // NOTE: fcmToken isn't saved to users/{uid} by any screen yet — that
    // gets added when the notifications feature (Prompt 6) registers each
    // device with Firebase Messaging. Until then `tokens` will just be
    // empty and this silently no-ops — the SMS backup below still fires,
    // so responders aren't left uninformed in the meantime.
    const tokens = respondersSnap.docs.map((d) => d.data().fcmToken).filter(Boolean);
    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "SOS Alert",
          body: `${residentName} triggered an SOS — respond now.`,
        },
        data: {type: "sos", alertId: event.params.alertId},
      });
    } else {
      logger.info("No fcmToken on file for responders yet — push skipped, SMS backup still sent.");
    }

    // 2. SMS to emergency contacts (Prompt 7 collection — safe to query even
    // before that screen exists, it will just return zero docs until then).
    const contactsSnap = await db
        .collection("emergency_contacts")
        .where("residentId", "==", alert.residentId)
        .get();
    const contactNumbers = contactsSnap.docs.map((d) => d.data().phone).filter(Boolean);
    await sendPhilSmsMessage(philSmsApiKey.value(), philSmsSenderId.value(), contactNumbers, smsMessage);

    // 3. Backup SMS to tanod/police (same message the offline on-device path
    // in sos_screen.dart sends, kept consistent).
    const responderNumbers = respondersSnap.docs.map((d) => d.data().phone).filter(Boolean);
    await sendPhilSmsMessage(philSmsApiKey.value(), philSmsSenderId.value(), responderNumbers, smsMessage);

    // 4. Log who got texted, for the resident-facing access/notify log.
    await snap.ref.update({
      contactsNotified: contactsSnap.docs.map((d) => d.id),
    });
  },
);

/**
 * Fires when a resident submits a regular (non-SOS) incident report via
 * report_form_screen.dart. Push-only to tanod — no SMS needed for
 * non-urgent reports.
 */
exports.onReportCreated = onDocumentCreated("reports/{reportId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const report = snap.data();

  const tanodSnap = await db.collection("users").where("role", "==", "tanod").get();
  const tokens = tanodSnap.docs.map((d) => d.data().fcmToken).filter(Boolean);

  if (tokens.length === 0) {
    logger.info("No fcmToken on file for tanod yet — push skipped for onReportCreated.");
    return;
  }

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: "New incident report",
      body: `A new "${report.type}" report was filed.`,
    },
    data: {type: "report", reportId: event.params.reportId},
  });
});

/**
 * Hashes a 6-digit recovery code with a random per-request salt before
 * storing it — mirrors the same approach the Flutter side uses for the PIN
 * itself (core/utils/pin_hash.dart). Note: a 6-digit code only has a
 * million possible values, so this hash mainly protects against casual
 * inspection, not a determined offline brute-force with direct DB read
 * access — the real protections against that are the short TTL, the
 * attempt cap, and this being deleted the moment it's used once.
 */
function hashRecoveryCode(code, salt) {
  return crypto.createHash("sha256").update(`${salt}:${code}`).digest("hex");
}

function buildGmailTransport(user, appPassword) {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {user, pass: appPassword},
  });
}

/**
 * Callable from the Flutter app (security_screen.dart's "Forgot PIN?"
 * flow, and pin_lock_screen.dart's recovery option) — generates a 6-digit
 * code, stores a hash of it under pin_recovery_codes/{uid} with a 10-minute
 * expiry, and emails the raw code to the resident's registered account
 * email via Gmail SMTP. requireAuth (built into onCall + the auth check
 * below) means this can only ever be triggered by someone already
 * logged into the account it's recovering — not a public "guess emails"
 * endpoint.
 */
exports.sendPinRecoveryCode = onCall(
  {secrets: [gmailAddress, gmailAppPassword]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    const uid = request.auth.uid;
    const email = request.auth.token.email;
    if (!email) {
      throw new HttpsError("failed-precondition", "No email on file for this account.");
    }

    const code = crypto.randomInt(0, 1000000).toString().padStart(6, "0");
    const salt = crypto.randomBytes(16).toString("hex");
    const codeHash = hashRecoveryCode(code, salt);
    const expiresAt = admin.firestore.Timestamp.fromMillis(
        Date.now() + PIN_RECOVERY_CODE_TTL_MINUTES * 60 * 1000,
    );

    await db.collection("pin_recovery_codes").doc(uid).set({
      codeHash,
      salt,
      expiresAt,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      const transport = buildGmailTransport(gmailAddress.value(), gmailAppPassword.value());
      await transport.sendMail({
        from: `Bantay Nuevo <${gmailAddress.value()}>`,
        to: email,
        subject: "Bantay Nuevo — Your recovery code",
        text: `Your verification code is ${code}. It expires in ` +
          `${PIN_RECOVERY_CODE_TTL_MINUTES} minutes. If you didn't request this, ` +
          "you can ignore this email — no changes were made to your account.",
      });
    } catch (err) {
      logger.error("sendPinRecoveryCode: email send failed", err);
      throw new HttpsError("internal", "Could not send the recovery email. Try again shortly.");
    }

    return {sent: true, expiresInMinutes: PIN_RECOVERY_CODE_TTL_MINUTES};
  },
);

/**
 * Verifies a code submitted from the app against what sendPinRecoveryCode
 * stored. Single-use — the doc is deleted on a successful match so the
 * same code can't be replayed. Rate-limited via PIN_RECOVERY_MAX_ATTEMPTS
 * so this can't be brute-forced by repeated guesses even within the
 * 10-minute window.
 */
exports.verifyPinRecoveryCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const submittedCode = String(request.data && request.data.code || "");

  const docRef = db.collection("pin_recovery_codes").doc(uid);
  const doc = await docRef.get();

  if (!doc.exists) {
    return {success: false, reason: "not_found"};
  }
  const data = doc.data();

  if (data.expiresAt.toMillis() < Date.now()) {
    await docRef.delete();
    return {success: false, reason: "expired"};
  }
  if (data.attempts >= PIN_RECOVERY_MAX_ATTEMPTS) {
    await docRef.delete();
    return {success: false, reason: "too_many_attempts"};
  }

  const submittedHash = hashRecoveryCode(submittedCode, data.salt);
  if (submittedHash !== data.codeHash) {
    await docRef.update({attempts: admin.firestore.FieldValue.increment(1)});
    return {success: false, reason: "incorrect"};
  }

  await docRef.delete();
  return {success: true};
});

/**
 * Callable from resident_home_screen.dart's "Share my location" card.
 * Texts every one of the caller's saved emergency contacts via PhilSMS,
 * same mechanism onSosCreated already uses — just a routine "here's where
 * I am" message, not a distress alert, and no Firestore doc is written at
 * all (unlike SOS, there's nothing here for tanod/police to track or
 * respond to). Runs entirely server-side so the resident never has to
 * leave the app or manually hit send in their own SMS app.
 */
exports.shareLocationViaSms = onCall(
  {secrets: [philSmsApiKey, philSmsSenderId]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    const uid = request.auth.uid;
    const lat = request.data && request.data.lat;
    const lng = request.data && request.data.lng;
    if (typeof lat !== "number" || typeof lng !== "number") {
      throw new HttpsError("invalid-argument", "lat/lng are required.");
    }

    const residentDoc = await db.collection("users").doc(uid).get();
    const residentName = residentDoc.exists ? residentDoc.data().name : "A resident";

    const contactsSnap = await db
        .collection("emergency_contacts")
        .where("residentId", "==", uid)
        .get();
    const contactNumbers = contactsSnap.docs.map((d) => d.data().phone).filter(Boolean);

    if (contactNumbers.length === 0) {
      throw new HttpsError("failed-precondition", "No emergency contacts saved.");
    }

    const mapsLink = `https://maps.google.com/?q=${lat},${lng}`;
    const message = `[Bantay Nuevo] ${residentName} is sharing their current location: ${mapsLink}`;

    await sendPhilSmsMessage(philSmsApiKey.value(), philSmsSenderId.value(), contactNumbers, message);

    return {sent: true, contactCount: contactNumbers.length};
  },
);
