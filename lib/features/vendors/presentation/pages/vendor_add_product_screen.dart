import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';
import 'package:palengkego/core/infrastructure/supabase_storage_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_product_form_controller.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import '../widgets/vendor_screen_header.dart';
import '../widgets/vendor_product_form_fields.dart';
import '../widgets/vendor_product_delete_dialog.dart';
import '../widgets/vendor_product_picker_sheet.dart';
import '../widgets/vendor_product_success_sheet.dart';

/// Vendor Add / Edit Product Screen
/// Pass [existingProduct] to enter edit mode.
class VendorAddProductScreen extends ConsumerStatefulWidget {
  final VendorProduct? existingProduct;

  const VendorAddProductScreen({super.key, this.existingProduct});

  @override
  ConsumerState<VendorAddProductScreen> createState() =>
      _VendorAddProductScreenState();
}

class _VendorAddProductScreenState
    extends ConsumerState<VendorAddProductScreen> {
  late final VendorProductFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VendorProductFormController(
      existingProduct: widget.existingProduct,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveProduct() {
    // Defer to next frame — same Flutter Web ScrollView deactivation fix.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.isSaving) return;
      _performSave();
    });
  }

  Future<void> _performSave() async {
    FocusScope.of(context).unfocus();

    final name = _controller.nameController.text.trim();
    final saved = await _controller.save(ref);
    if (!mounted || !saved) return;

    // Capture the navigator BEFORE the sheet opens (Web deactivation fix).
    final navigator = Navigator.of(context);
    await showVendorProductSuccessSheet(
      context: context,
      isEditMode: _controller.isEditMode,
      productName: name,
      navigator: navigator,
    );
  }

  void _deleteProduct() {
    // On Flutter Web, tapping a button inside a ScrollView can fire the
    // handler while the element tree is mid-layout / briefly deactivated.
    // Deferring to the next frame guarantees the tree is stable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _confirmDelete();
    });
  }

  Future<void> _confirmDelete() async {
    // All context lookups happen synchronously before any await.
    final navigator = Navigator.of(context);
    final productName = _controller.existingProduct!.name;

    final confirmed = await showVendorProductDeleteDialog(
      context,
      productName: productName,
    );
    if (!mounted || confirmed != true) return;

    final deleted = await _controller.delete(ref);
    if (!mounted || !deleted) return;
    navigator.pop();
  }

  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();
    final file = await ImagePickerHelper.pickImage(context);
    if (!mounted || file == null) return;
    final vendorId = ref.read(currentVendorIdProvider) ?? 'stall holder-001';
    try {
      final url = await ref.read(supabaseStorageServiceProvider).uploadFile(
        bucket: SupabaseStorageService.stallsBucket,
        path: '$vendorId/${SupabaseStorageService.objectName('product', file)}',
        file: file,
      );
      if (!mounted) return;
      _controller.setImageUrl(url ?? file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            VendorScreenHeader(
              title: c.isEditMode ? 'Edit Product' : 'Add Product',
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'General Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Upload Photo Area
                      VendorProductImagePicker(
                        imageUrl: c.imageUrl,
                        onTap: _pickImage,
                      ),
                      const SizedBox(height: 24),

                      // Product Name
                      const VendorProductLabel('Product Name'),
                      const SizedBox(height: 8),
                      VendorProductTextField(
                        hint: 'e.g. Organic Avocados',
                        controller: c.nameController,
                      ),
                      const SizedBox(height: 20),

                      // Category
                      const VendorProductLabel('Category'),
                      const SizedBox(height: 8),
                      VendorProductCategorySelector(
                        selectedCategory: c.selectedCategory,
                        onTap: () => showVendorProductPickerSheet(
                          context: context,
                          title: 'Select Category',
                          options: c.categories,
                          selected: c.selectedCategory,
                          onSelected: c.setCategory,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (c.selectedCategory == 'Meat') ...[
                        const VendorProductLabel('Subcategory'),
                        const SizedBox(height: 8),
                        VendorProductCategorySelector(
                          selectedCategory: c.selectedSubCategory,
                          onTap: () => showVendorProductPickerSheet(
                            context: context,
                            title: 'Select Subcategory',
                            options: const ['Beef', 'Pork'],
                            selected: c.selectedSubCategory,
                            onSelected: c.setSubCategory,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      const VendorProductLabel('Selling Unit'),
                      const SizedBox(height: 8),
                      VendorProductUnitPicker(
                        isPieceUnit: c.isPieceUnit,
                        onChanged: c.setUnit,
                      ),
                      const SizedBox(height: 20),

                      // Price field
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                VendorProductLabel(
                                  c.isPieceUnit == null
                                      ? 'Price'
                                      : (c.isPieceUnit!
                                            ? 'Price / pc'
                                            : 'Price / kg'),
                                ),
                                const SizedBox(height: 8),
                                VendorProductTextField(
                                  hint: '0.00',
                                  controller: c.priceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  prefixText: '₱ ',
                                  onChanged: (_) => c.refresh(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const VendorProductLabel('Discount %'),
                                const SizedBox(height: 8),
                                VendorProductTextField(
                                  hint: 'e.g. 15',
                                  controller: c.discountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  suffixText: '%',
                                  onChanged: (_) => c.refresh(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      VendorProductDiscountBanner(
                        discountedPrice: c.calculatedDiscountedPrice,
                      ),
                      const SizedBox(height: 20),

                      // Stock Quantity
                      const VendorProductLabel('Stock Quantity'),
                      const SizedBox(height: 8),
                      VendorProductTextField(
                        hint: '0',
                        controller: c.stockController,
                        keyboardType: TextInputType.number,
                        suffixText: c.isPieceUnit == null
                            ? ''
                            : (c.isPieceUnit! ? 'pcs' : 'kg'),
                        onChanged: (_) => c.refresh(),
                      ),
                      const SizedBox(height: 24),

                      // In Stock Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'In Stock',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Available for customers to buy',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: c.inStock,
                            onChanged: c.setInStock,
                            activeThumbColor: AppTheme.primaryGreen,
                            activeTrackColor: AppTheme.primaryGreen.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Save / Update Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: c.isSaving ? null : _saveProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            disabledBackgroundColor: AppTheme.muted,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: c.isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  c.isEditMode
                                      ? 'Update Product'
                                      : 'Save Product',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      // Delete Button — edit mode only
                      if (c.isEditMode) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: c.isSaving ? null : _deleteProduct,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                            label: const Text(
                              'Delete Product',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFEF4444),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
