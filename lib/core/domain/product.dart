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

  /// True if stock is low:
  /// - For piece items ('pc', 'piece'): stockQuantity <= 15
  /// - For kilo items ('kg'): stockQuantity <= 5
  bool get isLowStock {
    if (stockQuantity <= 0) return false;
    final u = unit.toLowerCase().trim();
    final isPiece = u == 'pc' || u == 'piece' || u == 'pieces';
    final threshold = isPiece ? 15.0 : 5.0;
    return stockQuantity <= threshold;
  }
}
