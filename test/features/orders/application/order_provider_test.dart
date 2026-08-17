import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/order_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';

void main() {
  test('orderServiceProvider exposes the app order service', () async {
    final container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(MockOrderRepository()),
        authProvider.overrideWith(_TestAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(orderServiceProvider.notifier), isA<OrderService>());

    final orders = await container.read(orderServiceProvider.future);
    expect(orders, isEmpty);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() => MockUsers.customer;
}
