import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

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
      expect(state.savedAddresses.length, 0);
      expect(state.isPaymentMethodConnected('cod'), true);
      expect(state.isPaymentMethodConnected('gcash'), false);
      expect(state.getPaymentMethodAccount('gcash'), isNull);
      expect(state.isPaymentMethodConnected('maya'), false);
    });

    test('connectPaymentAccount links method and sets it active', () {
      final notifier = container.read(preferencesProvider.notifier);
      notifier.connectPaymentAccount('maya', '+63 998 765 4321');

      final state = container.read(preferencesProvider);
      expect(state.isPaymentMethodConnected('maya'), true);
      expect(state.getPaymentMethodAccount('maya'), '+63 998 765 4321');
      expect(state.paymentMethod, 'maya');
    });

    test('disconnectPaymentAccount removes method and falls back to cod if active', () {
      final notifier = container.read(preferencesProvider.notifier);
      notifier.connectPaymentAccount('maya', '+63 998 765 4321');
      expect(container.read(preferencesProvider).paymentMethod, 'maya');

      notifier.disconnectPaymentAccount('maya');
      final state = container.read(preferencesProvider);
      expect(state.isPaymentMethodConnected('maya'), false);
      expect(state.getPaymentMethodAccount('maya'), isNull);
      expect(state.paymentMethod, 'cod');
    });

    test('removeDeliveryAddress removes the target address from savedAddresses', () {
      final notifier = container.read(preferencesProvider.notifier);
      // First add two addresses (first install is now empty)
      notifier.saveDeliveryAddress(
        const DeliveryAddress(label: 'Home', primaryAddress: 'Magsaysay Ave, Naga City', streetAddress: '123 Test St'),
      );
      notifier.saveDeliveryAddress(
        const DeliveryAddress(label: 'School', primaryAddress: 'Ateneo de Naga University', streetAddress: 'Ateneo Ave'),
      );
      final initialAddresses = container.read(preferencesProvider).savedAddresses;
      expect(initialAddresses.length, 2);

      final addressToRemove = initialAddresses.firstWhere((a) => a.label == 'Home');
      notifier.removeDeliveryAddress(addressToRemove);

      final updated = container.read(preferencesProvider).savedAddresses;
      expect(updated.length, 1);
      expect(updated.first.label, 'School');
    });
  });
}
