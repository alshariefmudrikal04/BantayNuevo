/// TEMPORARY — client-side EmailJS credentials, same category of
/// Blaze-plan workaround as PhilSmsConfig and CloudinaryConfig elsewhere
/// in this project. EmailJS is purpose-built for exactly this situation:
/// sending real email directly from client-side code, no backend/Cloud
/// Function/Blaze plan required — which is why it replaces the original
/// plan of using Firebase's "Trigger Email" extension (that extension
/// deploys as a Cloud Function under the hood, so it needs Blaze same as
/// any other Cloud Function — a dead end for this project's current plan).
///
/// SETUP (free tier, no credit card):
/// 1. Sign up at emailjs.com
/// 2. Email Services → Add New Service → connect Gmail (or any provider)
///    → note the SERVICE ID it gives you
/// 3. Email Templates → create a template with {{to_email}}, {{subject}},
///    {{message}} variables in the body → note the TEMPLATE ID
/// 4. Account → General → copy your PUBLIC KEY
/// 5. Account → General → "API Keys" section → enable "Allow EmailJS API
///    for non-browser applications" and copy the PRIVATE KEY — without
///    this step, EmailJS rejects requests that don't come from a real
///    browser page (it normally checks the Referer header for the
///    domains you whitelist under the service; a Flutter app calling its
///    REST API directly has no such header, so the private key is what
///    proves the request is legitimate instead).
class EmailJsConfig {
  EmailJsConfig._();

  static const serviceId = 'service_k3a6tii';
  static const templateId = 'template_2ntucms';
  static const publicKey = 'lNyqVqAQ6UD9zTn_k';
  static const privateKey = '9yCCAmmPjVQDzMjpxMkOm';

  static Uri get sendUrl => Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
}
