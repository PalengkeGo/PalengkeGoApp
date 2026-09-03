enum PaymentStatus {
  pending('Pending'),
  processing('Processing'), // payment intent created, awaiting webhook outcome
  paid('Paid'),
  failed('Failed'),
  refundRequested('Refund Requested'), // customer asked for a refund, awaiting vendor/admin
  refundPending('Refund Pending'), // refund issued, awaiting PayMongo settlement
  refunded('Refunded'); // refund confirmed (createRefund callable / webhook)

  const PaymentStatus(this.label);
  final String label;
}
