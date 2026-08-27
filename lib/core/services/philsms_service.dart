import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/philsms_config.dart';

/// Client-side PhilSMS sender — TEMPORARY stand-in for the Cloud Function
/// versions (onSosCreated / shareLocationViaSms in
/// firebase/functions/index.js) while Blaze isn't available. See
/// philsms_config.dart for the security tradeoff this accepts.
class PhilSmsService {
  /// Normalizes any common PH phone format into PhilSMS's expected
  /// "639171234567" shape — same normalization logic the Cloud Function
  /// version uses (toPhilSmsFormat in index.js), duplicated here since
  /// this now runs entirely client-side with no shared code between them.
  static String _toPhilSmsFormat(String rawNumber) {
    final digits = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('63') && digits.length == 12) return digits;
    if (digits.startsWith('0') && digits.length == 11) return '63${digits.substring(1)}';
    if (digits.startsWith('9') && digits.length == 10) return '63$digits';
    return digits; // best effort — PhilSMS will reject it if this guess is wrong
  }

  /// Sends one message to potentially many numbers in a single PhilSMS
  /// request (comma-joined recipients, same as the server version). Fails
  /// silently (returns false) rather than throwing, so one bad number or
  /// network hiccup never blocks the rest of an SOS flow — callers decide
  /// how much to surface that to the resident.
  static Future<bool> sendSms({required List<String> numbers, required String message}) async {
    if (numbers.isEmpty) return false;
    final recipients = numbers.map(_toPhilSmsFormat).join(',');
    try {
      final response = await http
          .post(
            PhilSmsConfig.sendUrl,
            headers: {
              'Authorization': 'Bearer ${PhilSmsConfig.apiKey}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'recipient': recipients,
              'sender_id': PhilSmsConfig.senderId,
              'type': 'plain',
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      return body?['status'] != 'error';
    } catch (_) {
      return false;
    }
  }
}
