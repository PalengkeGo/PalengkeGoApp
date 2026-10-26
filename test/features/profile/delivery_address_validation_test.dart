import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/profile/presentation/widgets/delivery_address_form_sheet.dart';

void main() {
  test('delivery address requires house, barangay, and a complete label', () {
    bool valid({
      String house = '  12 Main Street  ',
      String? barangay = 'Abella',
      String? label = 'Home',
      String customLabel = '',
    }) => isDeliveryAddressValid(
      house: house,
      barangay: barangay,
      label: label,
      customLabel: customLabel,
    );

    expect(valid(), isTrue);
    expect(valid(house: '  '), isFalse);
    expect(valid(barangay: null), isFalse);
    expect(valid(label: null), isFalse);
    expect(valid(label: 'Custom'), isFalse);
    expect(valid(label: 'Custom', customLabel: 'Parents'), isTrue);
  });
}
