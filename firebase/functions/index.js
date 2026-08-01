const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();
const db = admin.firestore();

// Set these once with:
//   firebase functions:secrets:set SEMAPHORE_API_KEY
//   firebase functions:secrets:set SEMAPHORE_SENDER_NAME
// (Semaphore is a PH-based SMS gateway — see semaphore.co. Free trial
// credits are enough for testing/defense demo purposes.)
const semaphoreApiKey = defineSecret("SEMAPHORE_API_KEY");
const semaphoreSenderName = defineSecret("SEMAPHORE_SENDER_NAME");

/**
 * Sends an SMS via the Semaphore API. Fails silently (logs only) so one bad
 * number never blocks the rest of the notification fan-out.
 */
async function sendSemaphoreSms(apiKey, senderName, numbers, message) {
  if (!numbers || numbers.length === 0) return;
  try {
    const res = await fetch("https://api.semaphore.co/api/v4/messages", {
      method: "POST",
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams({
        apikey: apiKey,
        number: numbers.join(","),
        message,
        sendername: senderName,
      }),
    });
    if (!res.ok) {
      logger.error("Semaphore SMS failed", {status: res.status, body: await res.text()});
    }
  } catch (err) {
    logger.error("Semaphore SMS threw", err);
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
  {document: "sos_alerts/{alertId}", secrets: [semaphoreApiKey, semaphoreSenderName]},
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
    await sendSemaphoreSms(semaphoreApiKey.value(), semaphoreSenderName.value(), contactNumbers, smsMessage);

    // 3. Backup SMS to tanod/police (same message the offline on-device path
    // in sos_screen.dart sends, kept consistent).
    const responderNumbers = respondersSnap.docs.map((d) => d.data().phone).filter(Boolean);
    await sendSemaphoreSms(semaphoreApiKey.value(), semaphoreSenderName.value(), responderNumbers, smsMessage);

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
