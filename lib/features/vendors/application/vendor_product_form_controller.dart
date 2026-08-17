import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/categories.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/core/utils/unit_helper.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';

/// Form state + save/delete orchestration for the Add/Edit Product screen.
/// The screen listens to this controller instead of calling setState.
class VendorProductFormController extends ChangeNotifier {
  VendorProductFormController({this.existingProduct}) {
    final p = existingProduct;
    if (p != null) {
      nameController.text = p.name;
      priceController.text = p.price.toStringAsFixed(0);
      stockController.text = p.stockQuantity % 1 == 0
          ? p.stockQuantity.toInt().toString()
          : p.stockQuantity.toString();
      if (p.discountPercentage != null && p.discountPercentage! > 0) {
        discountController.text = p.discountPercentage.toString();
      }
      if (p.category == 'Beef' || p.category == 'Pork') {
        selectedCategory = 'Meat';
        selectedSubCategory = p.category;
      } else {
        selectedCategory = p.category;
      }
      imageUrl = p.imageUrl;
      inStock = p.isActive;
      isPieceUnit = UnitHelper.isPieceProduct(p);
    }
  }

  final VendorProduct? existingProduct;

  bool get isEditMode => existingProduct != null;

  bool inStock = true;
  bool isSaving = false;
  String selectedCategory = '';
  String selectedSubCategory = '';
  String imageUrl = '';
  bool? isPieceUnit;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController discountController = TextEditingController();

  final List<String> categories = AppCategories.product;

  double? get calculatedDiscountedPrice {
    final double? price = double.tryParse(priceController.text.trim());
    final double? discount = double.tryParse(discountController.text.trim());
    if (price != null && discount != null && discount > 0) {
      return price * (1 - (discount / 100));
    }
    return null;
  }

  void setInStock(bool value) {
    inStock = value;
    _notify();
  }

  void setImageUrl(String value) {
    imageUrl = value;
    _notify();
  }

  void setCategory(String value) {
    selectedCategory = value;
    _notify();
  }

  void setSubCategory(String value) {
    selectedSubCategory = value;
    _notify();
  }

  void setUnit(bool value) {
    isPieceUnit = value;
    _notify();
  }

  /// Rebuild for text-field side effects (price preview, unit suffix).
  void refresh() => _notify();

  /// Returns true when the product was saved; messages are shown internally.
  Future<bool> save(WidgetRef ref) async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      AppServices.showError('Please enter a product name.');
      return false;
    }

    if (selectedCategory == 'Meat' && selectedSubCategory.isEmpty) {
      AppServices.showSnackBar('Please select a meat subcategory');
      return false;
    }

    if (imageUrl.isEmpty) {
      AppServices.showError('Please select a category.');
      return false;
    }
    if (priceController.text.trim().isEmpty) {
      AppServices.showError('Please enter a price.');
      return false;
    }
    if (isPieceUnit == null) {
      AppServices.showError('Please select a Selling Unit.');
      return false;
    }

    isSaving = true;
    _notify();

    try {
      final double price = double.tryParse(priceController.text.trim()) ?? 0.0;
      final double stock = double.tryParse(stockController.text.trim()) ?? 0.0;
      final double? discount = double.tryParse(discountController.text.trim());
      // Read ref synchronously BEFORE any await — safe even if widget unmounts later.
      final vendorId = ref.read(currentVendorIdProvider);
      if (vendorId == null) {
        isSaving = false;
        _notify();
        AppServices.showError('Vendor session required.');
        return false;
      }
      final manager = ref.read(vendorProductsManagerProvider(vendorId));

      final product = VendorProduct(
        id: isEditMode
            ? existingProduct!.id
            : 'p${DateTime.now().millisecondsSinceEpoch}',
        vendorId: vendorId,
        name: name,
        description: 'Fresh product from vendor',
        category: selectedCategory == 'Meat'
            ? selectedSubCategory
            : selectedCategory,
        price: price,
        unit: isPieceUnit! ? 'pc' : 'kg',
        imageUrl: imageUrl,
        isActive: inStock,
        stockQuantity: stock,
        discountPercentage: discount,
      );

      if (isEditMode) {
        await manager.updateProduct(product);
      } else {
        await manager.addProduct(product);
      }

      // Trigger Flash Sale notification if discount is present
      if (discount != null && discount > 0) {
        final notifService = ref.read(notificationServiceProvider);
        final title = 'Flash Sale on ${product.name}!';
        final body =
            '${discount.toInt()}% off on ${product.name}. Limited time only!';

        notifService.addNotification(
          AppNotification(
            id: 'flash_${product.id}_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.promo,
            target: NotificationTarget.customer,
            title: title,
            body: body,
            createdAt: DateTime.now(),
          ),
        );

        // outside app notification
        notifService.showLocalNotification(
          id: product.id.hashCode,
          title: title,
          body: body,
        );
      }

      isSaving = false;
      _notify();
      return true;
    } catch (e) {
      isSaving = false;
      _notify();
      AppServices.showError('Failed to save product: $e');
      return false;
    }
  }

  /// Returns true when the product was deleted; messages are shown internally.
  Future<bool> delete(WidgetRef ref) async {
    final productName = existingProduct!.name;
    final productId = existingProduct!.id;
    final vendorId = ref.read(currentVendorIdProvider);
    if (vendorId == null) {
      AppServices.showError('Vendor session required.');
      return false;
    }
    final manager = ref.read(vendorProductsManagerProvider(vendorId));

    isSaving = true;
    _notify();

    try {
      await manager.deleteProduct(productId);
      isSaving = false;
      _notify();
      // Use global key — zero context traversal, safe after any async gap.
      AppServices.showSnackBar('"$productName" has been deleted.');
      return true;
    } catch (e) {
      isSaving = false;
      _notify();
      AppServices.showError('Failed to delete product: $e');
      return false;
    }
  }

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    discountController.dispose();
    super.dispose();
  }
}
