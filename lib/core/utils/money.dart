/// Money helpers guaranteeing display/charge parity.
///
/// The trusted backend charges `Math.round(total * 100)` centavos, computed
/// once over the same double sum the app shows (request item order is
/// preserved end-to-end). Every peso figure the customer is asked to pay
/// must therefore be formatted FROM the identically-rounded centavos —
/// never from the raw double — or the screen can disagree with the charge
/// by one centavo.
library;

/// Server-identical centavo conversion: a single round of the total.
int centavosOf(double amount) => (amount * 100).round();

/// The amount the backend will actually charge, as a double.
double roundToCentavos(double amount) => centavosOf(amount) / 100;

/// Formats [amount] exactly as the backend rounds it, e.g. `₱1,234.50`.
String pesoOf(double amount) {
  final c = centavosOf(amount);
  final whole = c ~/ 100;
  final cents = (c % 100).toString().padLeft(2, '0');
  final wholeStr = whole
      .toString()
      .replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );
  return '₱$wholeStr.$cents';
}
