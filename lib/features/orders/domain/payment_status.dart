import 'package:json_annotation/json_annotation.dart';

@JsonEnum(valueField: 'label')
enum PaymentStatus {
  pending('Pending'),
  processing('Processing'), // payment intent created, awaiting webhook outcome
  paid('Paid'),
  failed('Failed'),
  refunded('Refunded'); // refund issued (createRefund callable / webhook)

  const PaymentStatus(this.label);
  final String label;
}
