import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:palengkego/features/cart/data/local_cart_repository.dart';
import 'package:palengkego/features/cart/data/supabase_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed backend cart write rolls back the local mirror', () async {
    SharedPreferences.setMockInitialValues({});
    final local = LocalCartRepository(await SharedPreferences.getInstance());
    final existing = _item('existing');
    await local.addToCart(existing);

    var attemptedWrite = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            '[]',
            200,
            headers: const {
              'content-type': 'application/json',
              'content-range': '*/0',
            },
            request: request,
          );
        }
        attemptedWrite = true;
        return http.Response(
          '{"message":"write failed"}',
          500,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final repository = SupabaseCartRepository('user-1', local, client);

    await expectLater(repository.addToCart(_item('new')), throwsA(anything));
    expect(attemptedWrite, isTrue);
    expect(await local.getCartItems(), [existing]);
    client.dispose();
  });
}

CartItem _item(String id) => CartItem(
  productId: id,
  vendorName: 'Stall',
  productName: id,
  price: 10,
  image: '',
);
