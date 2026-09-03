import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CustomerPreferencesNotifier', () {
    test('default state has pre-configured defaults', () {
      final state = container.read(preferencesProvider);
      expect(state.paymentMethod, 'cod');
      expect(state.savedAddresses.length, 2);
      expect(state.isPaymentMethodConnected('cod'), true);
      expect(state.isPaymentMethodConnected('gcash'), true);
      expect(state.getPaymentMethodAccount('gcash'), '0912 345 6789');
    });

    test('connectPaymentAccount links method and sets it active', () {
      final notifier = container.read(preferencesProvider.notifier);
      notifier.connectPaymentAccount('paymaya', '+63 998 765 4321');

      final state = container.read(preferencesProvider);
      expect(state.isPaymentMethodConnected('paymaya'), true);
      expect(state.getPaymentMethodAccount('paymaya'), '+63 998 765 4321');
      expect(state.paymentMethod, 'paymaya');
    });

    test('disconnectPaymentAccount removes method and falls back to cod if active', () {
      final notifier = container.read(preferencesProvider.notifier);
      notifier.connectPaymentAccount('paymaya', '+63 998 765 4321');
      expect(container.read(preferencesProvider).paymentMethod, 'paymaya');

      notifier.disconnectPaymentAccount('paymaya');
      final state = container.read(preferencesProvider);
      expect(state.isPaymentMethodConnected('paymaya'), false);
      expect(state.getPaymentMethodAccount('paymaya'), isNull);
      expect(state.paymentMethod, 'cod');
    });

    test('removeDeliveryAddress removes the target address from savedAddresses', () {
      final notifier = container.read(preferencesProvider.notifier);
      final initialAddresses = container.read(preferencesProvider).savedAddresses;
      expect(initialAddresses.length, 2);

      final addressToRemove = initialAddresses.first;
      notifier.removeDeliveryAddress(addressToRemove);

      final updated = container.read(preferencesProvider).savedAddresses;
      expect(updated.length, 1);
      expect(updated.first.label, 'School');
    });
  });
}
