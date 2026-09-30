import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/orders/data/supabase_order_repository.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';

SupabaseClient clientFor(
  Future<http.Response> Function(http.Request) handler,
) => SupabaseClient(
  'https://example.supabase.co',
  'test-key',
  httpClient: MockClient((request) async {
    final response = await handler(request);
    return http.Response.bytes(
      response.bodyBytes,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }),
);
http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'customer query resolves customer IDs and maps database statuses and quantities',
    () async {
      final client = clientFor((request) async {
        expect(request.url.path, '/functions/v1/read-orders');
        expect(jsonDecode(request.body)['vendor'], false);
        return json({
          'orders': [
            {
              'order_id': '260930-01',
              'customer_id': 'customer-row',
              'customer_uid': 'firebase-uid',
              'stall_holder_id': 'stall',
              'stall': {'stall_name': 'Fresh Fruit'},
              'order_status': 'delivered',
              'payment_status': 'paid',
              'items': [
                {
                  'product_id': 'product',
                  'product_name': 'Mango',
                  'quantity': 1.5,
                  'price_at_order': 100,
                  'unit': 'kg',
                },
              ],
            },
          ],
        });
      });
      addTearDown(client.dispose);
      final orders = await SupabaseOrderRepository(
        client: client,
        auth: _Auth(),
      ).getOrdersForCustomer('firebase-uid');
      expect(orders.single.customerUid, 'firebase-uid');
      expect(orders.single.status, OrderStatus.completed);
      expect(orders.single.vendorName, 'Fresh Fruit');
      expect(orders.single.items.single.quantity, 1.5);
    },
  );

  test(
    'database query failure does not return successful empty or local orders',
    () async {
      final client = clientFor(
        (_) async => json({'message': 'offline', 'code': '500'}, 500),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseOrderRepository(
          client: client,
          auth: _Auth(),
        ).getOrdersForCustomer('uid'),
        throwsA(isA<OrderFailure>()),
      );
    },
  );

  test(
    'failed status mutation is surfaced and never falls back to database writes',
    () async {
      var requests = 0;
      final client = clientFor((request) async {
        requests++;
        expect(request.url.path, '/functions/v1/update-order-status');
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        return json({
          'error': {
            'code': 'failed-precondition',
            'message': 'Order already completed',
          },
        }, 400);
      });
      addTearDown(client.dispose);
      await expectLater(
        SupabaseOrderRepository(
          client: client,
          auth: _Auth(),
        ).updateOrderStatus('order', OrderStatus.ready),
        throwsA(isA<OrderFailure>()),
      );
      expect(requests, 1);
    },
  );

  test(
    'remote product edits preserve zero stock and same names from different stalls',
    () async {
      final client = clientFor(
        (request) async => json([
          {
            'product_id': 'a',
            'stall_holder_id': 'one',
            'product_name': 'Mango',
            'unit': 'kg',
            'price_per_kg': 100,
            'stock_quantity': 0,
            'is_in_stock': true,
          },
          {
            'product_id': 'b',
            'stall_holder_id': 'two',
            'product_name': 'Mango',
            'unit': 'kg',
            'price_per_kg': 200,
            'stock_quantity': 3,
            'is_in_stock': true,
          },
          {
            'product_id': 'c',
            'stall_holder_id': 'one',
            'product_name': 'Hidden',
            'is_visible': false,
          },
        ]),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final products = await container.read(allProductsProvider.future);
      expect(products, hasLength(2));
      expect(products.singleWhere((p) => p.id == 'a').stockQuantity, 0);
      expect(products.singleWhere((p) => p.id == 'a').isActive, false);
      expect(products.singleWhere((p) => p.id == 'b').price, 200);
    },
  );

  test(
    'failed product save propagates instead of being saved only locally',
    () async {
      final client = clientFor((request) async {
        if (request.url.path.endsWith('stall_holders')) {
          return json({'stall_holder_id': 'stall'});
        }
        return json({'message': 'Write rejected', 'code': '42501'}, 403);
      });
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          authProvider.overrideWith(_Vendor.new),
        ],
      );
      addTearDown(container.dispose);
      const product = VendorProduct(
        id: 'product',
        vendorId: 'stall',
        name: 'Mango',
        description: '',
        category: 'Fruits',
        price: 100,
        unit: 'kg',
        imageUrl: '',
        stockQuantity: 3,
      );
      await expectLater(
        container
            .read(vendorProductsManagerProvider('stall'))
            .updateProduct(product),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'firebase-token';
}

class _Vendor extends AuthNotifier {
  @override
  AppUser? build() => const AppUser(
    uid: 'vendor',
    email: 'vendor@test.invalid',
    role: UserRole.vendor,
  );
}
