import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../config/emailjs_config.dart';

/// Client-side email sender via EmailJS — the actual "send a real email"
/// mechanism for this project, replacing the original Firebase "Trigger
/// Email" extension plan (that extension is a Cloud Function under the
/// hood and needs Blaze, same constraint as everything else client-side
/// in this codebase). See emailjs_config.dart for full setup steps and
/// the security tradeoff this accepts (same category as PhilSmsService).
class EmailService {
  /// Fails silently (returns false) rather than throwing — same pattern
  /// as PhilSmsService.sendSms, so a failed email never blocks or
  /// misreports the actual decision it's attached to (see
  /// AdminRepository.approveVerification/rejectVerification, which
  /// already wrap this call in try/catch for exactly that reason).
  static Future<bool> send({required String to, required String subject, required String body}) async {
    try {
      final response = await http
          .post(
            EmailJsConfig.sendUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': EmailJsConfig.serviceId,
              'template_id': EmailJsConfig.templateId,
              'user_id': EmailJsConfig.publicKey,
              'accessToken': EmailJsConfig.privateKey,
              'template_params': {
                'to_email': to,
                'subject': subject,
                'message': body,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) return true;

      // Previously this just returned false with nothing else — meaning a
      // misconfigured EmailJS template, an expired private key, or a
      // hit rate limit all looked identical to "app is offline" from the
      // caller's side, with zero way to tell them apart. This at least
      // surfaces the real reason in the debug console during testing.
      debugPrint('EmailService: send failed (${response.statusCode}): ${response.body}');
      return false;
    } catch (e) {
      debugPrint('EmailService: send threw: $e');
      return false;
    }
  }
}
