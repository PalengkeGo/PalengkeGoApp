import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/checkout/domain/payment_selection.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

void main() {
  group('CardSelectionData', () {
    test('displayLabel uses safe card brand and last four digits only', () {
      const card = CardSelectionData(
        brand: 'Visa',
        last4: '4242',
        expiry: '12/30',
        cardholderName: 'Juan Dela Cruz',
      );

      expect(card.displayLabel, 'Visa **** 4242');
      expect(card.displayLabel, isNot(contains('12/30')));
      expect(card.displayLabel, isNot(contains('Juan Dela Cruz')));
    });
  });

  group('PaymentSelectionResult', () {
    test('can represent cash on delivery without card data', () {
      const result = PaymentSelectionResult(method: 'cod');

      expect(result.method, 'cod');
      expect(result.cardData, isNull);
    });

    test('can represent card selection with display-safe card data', () {
      const card = CardSelectionData(
        brand: 'Mastercard',
        last4: '1234',
        expiry: '01/31',
        cardholderName: 'Maria Santos',
      );
      const result = PaymentSelectionResult(method: 'card', cardData: card);

      expect(result.method, 'card');
      expect(result.cardData?.displayLabel, 'Mastercard **** 1234');
    });
  });

  group('DeliveryAddress', () {
    test('displayLine returns primary address when street is empty', () {
      const address = DeliveryAddress(primaryAddress: 'Magsaysay Ave');

      expect(address.displayLine, 'Magsaysay Ave');
    });

    test('displayLine combines street and primary address', () {
      const address = DeliveryAddress(
        primaryAddress: 'Naga City',
        streetAddress: '123 Magsaysay Avenue',
      );

      expect(address.displayLine, '123 Magsaysay Avenue, Naga City');
    });
  });
}
