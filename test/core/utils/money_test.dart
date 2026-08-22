import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/utils/money.dart';

void main() {
  test('centavosOf mirrors the backend single-round', () {
    expect(centavosOf(79.5), 7950);
    expect(centavosOf(0.1 + 0.2), 30); // 0.30000000000000004 → 30, not 30.00…
    expect(centavosOf(15.5 + 49 + 15), 7950);
  });

  test('pesoOf formats from the rounded centavos', () {
    expect(pesoOf(79.5), '₱79.50');
    expect(pesoOf(0.1 + 0.2), '₱0.30');
    expect(pesoOf(1234.5), '₱1,234.50');
    expect(pesoOf(0), '₱0.00');
  });

  test('roundToCentavos keeps display and charge identical', () {
    final displayed = roundToCentavos(15.5 + 49 + 15);
    expect(displayed * 100, 7950); // what the server charges, as a double
  });
}
