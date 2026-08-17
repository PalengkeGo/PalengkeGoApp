import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:palengkego/core/utils/quantity_format.dart';

part 'order_line_item.freezed.dart';
part 'order_line_item.g.dart';

@freezed
abstract class OrderLineItem with _$OrderLineItem {
  const OrderLineItem._(); // allows custom methods/getters

  const factory OrderLineItem({
    required String productId,
    required String productName,
    required double quantity,
    required double unitPrice,

    /// 'kg' or 'pc'
    @Default('kg') String unit,
    @Default('') String image,
  }) = _OrderLineItem;

  factory OrderLineItem.fromJson(Map<String, dynamic> json) =>
      _$OrderLineItemFromJson(json);

  double get total => unitPrice * quantity;

  String get quantityLabel => formatQuantityLabel(quantity, unit);
}
