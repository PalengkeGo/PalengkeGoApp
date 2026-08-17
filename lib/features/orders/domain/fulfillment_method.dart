import 'package:json_annotation/json_annotation.dart';

@JsonEnum(valueField: 'label')
enum FulfillmentMethod {
  delivery('Delivery'),
  pickup('Pick-up');

  const FulfillmentMethod(this.label);
  final String label;
}
