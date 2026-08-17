class CardSelectionData {
  const CardSelectionData({
    required this.brand,
    required this.last4,
    required this.expiry,
    required this.cardholderName,
  });

  final String brand;
  final String last4;
  final String expiry;
  final String cardholderName;

  String get displayLabel => '$brand **** $last4';
}

class PaymentSelectionResult {
  const PaymentSelectionResult({required this.method, this.cardData});

  final String method;
  final CardSelectionData? cardData;
}
