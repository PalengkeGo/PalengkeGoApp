import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
abstract class VendorProduct with _$VendorProduct {
  const VendorProduct._(); // Added to allow custom methods/getters

  const factory VendorProduct({
    required String id,
    required String vendorId,
    required String name,
    required String description,
    required String category,
    required double price,

    /// 'kg' or 'pc'
    @Default('kg') String unit,
    required String imageUrl,
    @Default(true) bool isActive,
    @Default(0.0) double stockQuantity,

    /// Captures the stock at creation time for low-stock % calculation.
    @Default(0.0) double initialStockQuantity,
    double? discountPercentage,
  }) = _VendorProduct;

  factory VendorProduct.fromJson(Map<String, dynamic> json) =>
      _$VendorProductFromJson(json);
  factory VendorProduct.fromMap(Map<String, dynamic> map) =>
      VendorProduct.fromJson(map);

  Map<String, dynamic> toMap() => toJson();

  bool get hasDiscount => discountPercentage != null && discountPercentage! > 0;
  double get discountedPrice =>
      hasDiscount ? price * (1 - (discountPercentage! / 100)) : price;

  /// True if stock ≤ 10% of initial stock (or ≤10 absolute if initial unknown).
  bool get isLowStock {
    if (stockQuantity <= 0) return false;
    return initialStockQuantity > 0
        ? stockQuantity / initialStockQuantity <= 0.10
        : stockQuantity <= 10;
  }
}
