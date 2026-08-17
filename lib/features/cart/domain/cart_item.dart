import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:palengkego/core/utils/quantity_format.dart';

part 'cart_item.freezed.dart';
part 'cart_item.g.dart';

@freezed
abstract class CartItem with _$CartItem {
  const CartItem._(); // allows custom methods/getters

  const factory CartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required double price,

    /// 'kg' or 'pc'
    @Default('kg') String unit,
    required String image,
    @Default(1.0) double quantity,
    @Default(true) bool selected,
    @Default(10.0) double stockQuantity,
  }) = _CartItem;

  factory CartItem.fromJson(Map<String, dynamic> json) =>
      _$CartItemFromJson(json);

  double get total => price * quantity;

  String get quantityLabel => formatQuantityLabel(quantity, unit);
}
