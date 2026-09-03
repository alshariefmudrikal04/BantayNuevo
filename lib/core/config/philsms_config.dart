/// TEMPORARY — client-side PhilSMS credentials, the same Blaze-plan
/// workaround CloudinaryConfig documents for evidence storage. The "real"
/// design (see firebase/functions/index.js's onSosCreated /
/// shareLocationViaSms) keeps these as Cloud Functions secrets so they
/// never reach the client at all — once Blaze is available, delete this
/// file and philsms_service.dart, deploy those two functions instead, and
/// nothing else in the app needs to change (sos_repository.dart already
/// only ever writes the alert doc; the function does the rest).
///
/// Paste your real values from philsms.com below: Dashboard → API →
/// your API key, and your approved Sender ID / Sender Name.
///
/// SECURITY NOTE — read this before shipping beyond a thesis demo: unlike
/// CloudinaryConfig's unsigned upload preset (which is *designed* to be
/// public), this API key genuinely lets anyone who extracts it from your
/// compiled app send SMS on your account's balance. Acceptable for a
/// bounded demo; not something to leave client-side long-term.
class PhilSmsConfig {
  PhilSmsConfig._();

  static const apiKey = 'PASTE_YOUR_PHILSMS_API_KEY_HERE';
  static const senderId = 'PASTE_YOUR_SENDER_ID_HERE';

  static Uri get sendUrl => Uri.parse('https://dashboard.philsms.com/api/v3/sms/send');
}
