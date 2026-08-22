import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';

/// Client-side orchestration of the PayMongo Payment Intent flow
/// (docs/PAYMENTS_PAYMONGO.md):
///
///  1. `createPaymentIntent` callable (trusted backend, SECRET key) →
///     `{intentId, clientKey, amount}`.
///  2. Create a Payment Method with the PUBLIC key (`pk_…`) — e-wallets need
///     only the type; card details never touch our backend.
///  3. Attach the method to the intent (public key + client key) → the
///     response's `next_action.redirect.url` sends the customer to the
///     e-wallet approval page.
///  4. The verified webhook flips the order's `paymentStatus`; the app simply
///     watches the order document.
///
/// SECURITY: only the PUBLIC key ever ships in the app. Amounts are computed
/// server-side; this client never sends one.
class PayMongoService {
  PayMongoService({
    required FirebaseFunctions functions,
    required this.publicKey,
    http.Client? client,
  })  : _functions = functions,
        _client = client ?? http.Client();

  static const String paymongoApiUrl = 'https://api.paymongo.com/v1';

  final FirebaseFunctions _functions;
  final String publicKey;
  final http.Client _client;

  /// App payment-method ids → PayMongo payment-method types.
  static String? mapMethodToType(String method) {
    switch (method) {
      case 'gcash':
        return 'gcash';
      case 'paymaya':
      case 'maya':
        return 'maya';
      default:
        return null; // 'card' needs details; 'cod'/'cop' never reach here
    }
  }

  /// Extracts the redirect URL (if any) from an attach-response body.
  /// Cards without 3DS may need no redirect — returns null then.
  static String? redirectUrlFromAttachResponse(Map<String, dynamic> body) {
    final attributes =
        (body['data'] as Map<String, dynamic>?)?['attributes']
            as Map<String, dynamic>?;
    final nextAction = attributes?['next_action'] as Map<String, dynamic>?;
    final redirect = nextAction?['redirect'] as Map<String, dynamic>?;
    final url = redirect?['url'];
    return url is String && url.isNotEmpty ? url : null;
  }

  String get _publicAuthHeader =>
      'Basic ${base64Encode(utf8.encode('$publicKey:'))}';

  /// Starts a payment for [orderId]. Creates the intent via the trusted
  /// backend, then a payment method + attach with the public key.
  ///
  /// Returns the redirect URL when the customer must approve in an external
  /// app/browser (GCash/Maya), or an intent id with no redirect when the
  /// payment is already processing (some card flows). Throws
  /// [CardPaymentUnsupportedError] for 'card' — the app deliberately stores
  /// no card credentials, so a card form must collect them first.
  Future<PaymentSession> startPayment({
    required String orderId,
    required String method,
    String? returnUrl,
  }) async {
    final type = mapMethodToType(method);
    if (type == null) {
      throw CardPaymentUnsupportedError();
    }

    // 1. Trusted backend creates the intent (server-side amount).
    final result = await _functions
        .httpsCallable('createPaymentIntent')
        .call({'orderId': orderId, 'paymentMethod': method});
    final data = Map<String, dynamic>.from(result.data as Map);
    final intentId = data['intentId'] as String?;
    final clientKey = data['clientKey'] as String?;
    if (intentId == null || clientKey == null) {
      throw const PaymentInitiationException(
          'Backend did not return a payment intent');
    }

    // 2. Create the e-wallet payment method (public key).
    final paymentMethodId = await _createPaymentMethod(type);
    if (paymentMethodId == null) {
      throw const PaymentInitiationException(
          'PayMongo rejected the payment method');
    }

    // 3. Attach → next_action redirect.
    final redirectUrl = await _attachPaymentMethod(
      intentId: intentId,
      clientKey: clientKey,
      paymentMethodId: paymentMethodId,
      returnUrl: returnUrl,
    );

    return PaymentSession(
      orderId: orderId,
      intentId: intentId,
      redirectUrl: redirectUrl,
    );
  }

  Future<String?> _createPaymentMethod(String type) async {
    final response = await _client.post(
      Uri.parse('$paymongoApiUrl/payment_methods'),
      headers: {
        'Authorization': _publicAuthHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'data': {
          'attributes': {'type': type},
        },
      }),
    );
    if (response.statusCode != 200) {
      throw PaymentInitiationException(
        'Payment method creation failed (${response.statusCode})',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final id = (body['data'] as Map<String, dynamic>?)?['id'];
    return id is String ? id : null;
  }

  Future<String?> _attachPaymentMethod({
    required String intentId,
    required String clientKey,
    required String paymentMethodId,
    String? returnUrl,
  }) async {
    final attributes = <String, dynamic>{
      'client_key': clientKey,
      'payment_method': paymentMethodId,
      if (returnUrl != null && returnUrl.isNotEmpty) 'return_url': returnUrl,
    };
    final response = await _client.post(
      Uri.parse('$paymongoApiUrl/payment_intents/$intentId/attach'),
      headers: {
        'Authorization': _publicAuthHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'data': {'attributes': attributes},
      }),
    );
    if (response.statusCode != 200) {
      throw PaymentInitiationException(
        'Attaching the payment method failed (${response.statusCode})',
      );
    }
    return redirectUrlFromAttachResponse(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

/// A payment in flight. [redirectUrl] is null when no external approval is
/// needed — the webhook is authoritative either way.
class PaymentSession {
  const PaymentSession({
    required this.orderId,
    required this.intentId,
    this.redirectUrl,
  });

  final String orderId;
  final String intentId;
  final String? redirectUrl;
}

class PaymentInitiationException implements Exception {
  const PaymentInitiationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The app stores no card credentials (only a display label), so 'card'
/// cannot be paid until a card-details form exists. See
/// add_credit_card_screen.dart — card data is popped as CardSelectionData
/// and discarded after masking.
class CardPaymentUnsupportedError implements Exception {
  @override
  String toString() =>
      'In-app card payments need a card-details form; use GCash/Maya or cash.';
}

/// The active [PayMongoService], wired to the Firebase Functions instance
/// used by every other trusted call. Requires Firebase mode.
final paymongoServiceProvider = Provider<PayMongoService>((ref) {
  return PayMongoService(
    functions: ref.watch(firebaseFunctionsProvider),
    publicKey: ref.watch(appConfigProvider).paymongoPublicKey,
  );
});
