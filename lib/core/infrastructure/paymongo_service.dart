import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:palengkego/core/config/app_config.dart';

/// Service to handle PayMongo API requests.
///
/// SECURITY NOTICE: NEVER use your PayMongo Secret Key in the Flutter app.
/// Payment intents are created on your backend (Firebase Functions / Supabase
/// Edge Functions), which holds the secret key. This client only talks to
/// that backend, never to PayMongo directly.
class PayMongoService {
  PayMongoService({required this.backendUrl});

  /// Backend endpoint that creates PayMongo payment intents/links.
  /// Supplied via `--dart-define=PAYMONGO_BACKEND_URL=...` (see [AppConfig]).
  final String backendUrl;

  /// Asks the app's backend to create a payment link for [amount] (PHP).
  /// Returns the PayMongo `checkout_url`, or null when the backend rejects
  /// the request.
  Future<String?> createPaymentLink(double amount, String description) async {
    if (backendUrl.isEmpty) {
      throw StateError(
        'PAYMONGO_BACKEND_URL is not configured. Pass '
        '--dart-define=PAYMONGO_BACKEND_URL=https://your-backend/create-payment '
        'and point it at your payment endpoint.',
      );
    }

    final url = Uri.parse(backendUrl);

    final payload = {'amount': amount, 'description': description};

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Add your app's authentication token here (e.g. Firebase App Check
          // / Auth ID token) so the backend can verify who is paying.
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['checkout_url'] as String?;
      }
      // Use a proper logger instead of print in production.
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// The active [PayMongoService], wired to the `PAYMONGO_BACKEND_URL`
/// dart-define through [AppConfig] like every other backend.
final paymongoServiceProvider = Provider<PayMongoService>((ref) {
  return PayMongoService(
    backendUrl: ref.watch(appConfigProvider).paymongoBackendUrl,
  );
});
