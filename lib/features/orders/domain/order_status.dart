import 'package:json_annotation/json_annotation.dart';

@JsonEnum(valueField: 'label')
enum OrderStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  preparing('Preparing'),
  ready('Ready'),
  outForDelivery('Out for Delivery'),
  completed('Completed'),
  cancelled('Cancelled'),
  rejected('Rejected');

  const OrderStatus(this.label);
  final String label;
}
