import 'dart:convert';
import 'package:http/http.dart' as http;

/// Configure your deployed Cloud Functions base URL here.
/// Example after deploy:
///   https://asia-south1-safeher-g546.cloudfunctions.net/api
const String kFunctionsBaseUrl = String.fromEnvironment(
  'SAFEHER_FUNCTIONS_BASE_URL',
  defaultValue: '',
);

class VerificationApiClient {
  const VerificationApiClient();

  Uri _url(String path) {
    if (kFunctionsBaseUrl.isEmpty) {
      throw StateError('Functions base URL not configured. Set SAFEHER_FUNCTIONS_BASE_URL or hardcode kFunctionsBaseUrl.');
    }
    final base = kFunctionsBaseUrl.endsWith('/') ? kFunctionsBaseUrl.substring(0, kFunctionsBaseUrl.length - 1) : kFunctionsBaseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  Future<void> startVerify({
    required String phone,
    required String userId,
    required String contactId,
  }) async {
    final resp = await http.post(
      _url('/verify/start'),
      headers: { 'Content-Type': 'application/json' },
      body: jsonEncode({ 'phone': phone, 'userId': userId, 'contactId': contactId }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Verify start failed: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw StateError('Verify start error: ${resp.body}');
    }
  }

  Future<bool> checkVerify({
    required String phone,
    required String code,
    required String userId,
    required String contactId,
  }) async {
    final resp = await http.post(
      _url('/verify/check'),
      headers: { 'Content-Type': 'application/json' },
      body: jsonEncode({ 'phone': phone, 'code': code, 'userId': userId, 'contactId': contactId }),
    );
    if (resp.statusCode == 200) {
      return true;
    }
    return false;
  }
}
