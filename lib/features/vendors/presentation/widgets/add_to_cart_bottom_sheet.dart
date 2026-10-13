import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';

/// Outcome of the add-to-cart bottom sheet, so the caller can decide the toast
/// and whether to prompt login (a signed-out user's very first add).
enum AddToCartResult {
  /// Nothing was added (the sheet was dismissed or the product is unavailable).
  cancelled,

  /// The item was added; no login prompt needed.
  added,

  /// The item was added but it was a signed-out user's FIRST item — the caller
  /// should prompt login (the item is saved to the device cart and will merge).
  addedLoginRequired,
}

class AddToCartBottomSheet extends ConsumerStatefulWidget {
  final String vendorName;
  final VendorProduct product;

  const AddToCartBottomSheet({
    super.key,
    required this.vendorName,
    required this.product,
  });

  static Future<AddToCartResult?> show(
    BuildContext context, {
    required String vendorName,
    required VendorProduct product,
  }) {
    return showModalBottomSheet<AddToCartResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.6),
      builder: (context) =>
          AddToCartBottomSheet(vendorName: vendorName, product: product),
    );
  }

  @override
  ConsumerState<AddToCartBottomSheet> createState() =>
      _AddToCartBottomSheetState();
}

class _AddToCartBottomSheetState extends ConsumerState<AddToCartBottomSheet> {
  late final List<String> _weights;
  late final List<double> _weightMultipliers;
  int _selectedWeightIndex = 0;
  int _quantity = 1;
  bool _isSubmitting = false;
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    final isPiece = _isPieceProduct();
    final u = widget.product.unit.trim();
    final unitStr = u.isEmpty ? 'pc' : u;

    if (isPiece) {
      _weights = ['1 $unitStr', '2 $unitStr', '3 $unitStr', '5 $unitStr'];
      _weightMultipliers = [1.0, 2.0, 3.0, 5.0];
    } else {
      _weights = ['1/4 kg', '1/2 kg', '3/4 kg', '1 kg'];
      _weightMultipliers = [0.25, 0.5, 0.75, 1.0];
    }

    _selectedWeightIndex = 0;
    _quantity = 1;
    _qtyController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  /// Returns true when the product is sold per-piece/pack/item rather than weight.
  bool _isPieceProduct() {
    final unit = widget.product.unit.toLowerCase().trim();
    return unit != 'kg' && unit != 'kilo' && unit != 'g' && unit != 'gram';
  }

  double get _unitWeight => _weightMultipliers[_selectedWeightIndex];
  double get _totalQuantity => _unitWeight * _quantity;
  double get _computedTotalPrice =>
      widget.product.discountedPrice * _totalQuantity;
  bool get _exceedsStock => _totalQuantity > widget.product.stockQuantity;

  String _formatStock(double qty) {
    return qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
  }

  String _priceLabel(double basePrice) {
    final unit = _isPieceProduct() ? 'pc' : 'kg';
    return '₱${basePrice.toStringAsFixed(2)}/$unit';
  }

  void _showImagePreview(BuildContext context) {
    final imagePath = widget.product.imageUrl.isNotEmpty
        ? widget.product.imageUrl
        : productFallbackImage(widget.product.name, widget.product.category);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.black,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                  maxWidth: 480,
                ),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: AdaptiveImage(
                    imagePath,
                    fallbackPath: productFallbackImage(
                      widget.product.name,
                      widget.product.category,
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.product.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Pinch or drag to zoom',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basePrice = widget.product.discountedPrice;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.25),
            offset: Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle and close button
              Row(
                children: [
                  const SizedBox(width: 36),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Product Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clickable Product Image
                  GestureDetector(
                    onTap: () => _showImagePreview(context),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: AdaptiveImage(
                              widget.product.imageUrl.isNotEmpty
                                  ? widget.product.imageUrl
                                  : productFallbackImage(
                                      widget.product.name,
                                      widget.product.category,
                                    ),
                              fallbackPath: productFallbackImage(
                                widget.product.name,
                                widget.product.category,
                              ),
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(
                                  Icons.image_rounded,
                                  size: 32,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.product.category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _priceLabel(basePrice),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (widget.product.stockQuantity <= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 14,
                                  color: Color(0xFFDC2626),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Out of stock',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (widget.product.isLowStock ||
                            widget.product.stockQuantity <= 5)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 14,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Only ${_formatStock(widget.product.stockQuantity)} ${widget.product.unit} left!',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 14,
                                  color: Color(0xFF059669),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'In stock: ${_formatStock(widget.product.stockQuantity)} ${widget.product.unit}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Option Grid Header
              Row(
                children: [
                  Text(
                    _isPieceProduct() ? 'Select Quantity' : 'Select Weight',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Price per option',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2x2 Options Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _weights.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.35,
                ),
                itemBuilder: (context, index) {
                  final weightLabel = _weights[index];
                  final multiplier = _weightMultipliers[index];
                  final optionPrice = basePrice * multiplier;
                  final isSelected = index == _selectedWeightIndex;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedWeightIndex = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF047857)
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  weightLabel,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? const Color(0xFF064E3B)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₱${optionPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF047857)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFF047857),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),

              // Quantity Stepper Row
              Row(
                children: [
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _exceedsStock
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _exceedsStock
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFE2E8F0),
                        width: _exceedsStock ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roundQuantityButton(
                          icon: Icons.remove_rounded,
                          onTap: () {
                            if (_quantity > 1) {
                              setState(() {
                                _quantity--;
                                _qtyController.text = _quantity.toString();
                              });
                            }
                          },
                          foreground: _quantity > 1
                              ? const Color(0xFF047857)
                              : const Color(0xFF94A3B8),
                          background: Colors.transparent,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: 36,
                            child: TextField(
                              controller: _qtyController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _exceedsStock
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF1E293B),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                final parsed = int.tryParse(val.trim());
                                setState(() {
                                  _quantity = parsed ?? 1;
                                });
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            _isPieceProduct() ? 'pc' : 'kg',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _exceedsStock
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        _roundQuantityButton(
                          icon: Icons.add_rounded,
                          onTap: () {
                            final nextTotal = _unitWeight * (_quantity + 1);
                            if (nextTotal <= widget.product.stockQuantity) {
                              setState(() {
                                _quantity++;
                                _qtyController.text = _quantity.toString();
                              });
                            } else {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                const SnackBar(
                                  content: Text('Maximum stock reached'),
                                ),
                              );
                            }
                          },
                          background: const Color(0xFF063A2F),
                          foreground: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Computed Notice Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFEF08A).withValues(alpha: 0.6),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Price will be automatically computed based on your selected weight and quantity.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_exceedsStock) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The only stock left is ${_formatStock(widget.product.stockQuantity)} ${widget.product.unit}, which is not equal to the ${_formatStock(_totalQuantity)} ${widget.product.unit} you are asking for.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Add to Cart Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isSubmitting ||
                          widget.product.stockQuantity <= 0 ||
                          _exceedsStock ||
                          _totalQuantity <= 0)
                      ? null
                      : () async {
                          if (!mounted) return;
                          if (widget.product.stockQuantity <= 0) {
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              const SnackBar(
                                content: Text('Maximum stock reached'),
                              ),
                            );
                            return;
                          }
                          if (_exceedsStock) {
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'The only stock left is ${_formatStock(widget.product.stockQuantity)} ${widget.product.unit}, which is not equal to what you are asking.',
                                ),
                                backgroundColor: const Color(0xFFDC2626),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          final user = ref.read(authProvider);
                          final isSignedIn =
                              user != null && user.uid.isNotEmpty;

                          if (!isSignedIn) {
                            final goLogin = await showDialog<bool>(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text(
                                  'Log In Required',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                content: const Text(
                                  'Please log in or sign up to add items to your cart.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, height: 1.4),
                                ),
                                actionsAlignment: MainAxisAlignment.center,
                                actionsPadding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  16,
                                ),
                                actions: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogCtx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF063A2F),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text('Log In / Sign Up'),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx, false),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (goLogin == true && context.mounted) {
                              final didLogin = await Navigator.pushNamed(
                                context,
                                AppRoutes.login,
                              );
                              final nowUser = ref.read(authProvider);
                              if ((didLogin == true ||
                                      (nowUser != null &&
                                          nowUser.uid.isNotEmpty)) &&
                                  context.mounted) {
                                final cartItem = CartItem(
                                  productId: widget.product.id.isNotEmpty
                                      ? widget.product.id
                                      : 'prod_${widget.vendorName}_${widget.product.name}_${widget.product.unit}',
                                  vendorName: widget.vendorName,
                                  productName: widget.product.name,
                                  price: basePrice,
                                  unit: widget.product.unit,
                                  image: widget.product.imageUrl.isNotEmpty
                                      ? widget.product.imageUrl
                                      : productFallbackImage(
                                          widget.product.name,
                                          widget.product.category,
                                        ),
                                  quantity: _totalQuantity,
                                  stockQuantity: widget.product.stockQuantity,
                                );
                                await ref
                                    .read(cartItemsProvider.notifier)
                                    .addToCart(cartItem);
                                if (context.mounted) {
                                  Navigator.pop(
                                    context,
                                    AddToCartResult.added,
                                  );
                                }
                                return;
                              }
                            }

                            // User did not log in: do NOT add to cart!
                            return;
                          }

                          setState(() {
                            _isSubmitting = true;
                          });

                          try {
                            final cartItem = CartItem(
                              productId: widget.product.id.isNotEmpty
                                  ? widget.product.id
                                  : 'prod_${widget.vendorName}_${widget.product.name}_${widget.product.unit}',
                              vendorName: widget.vendorName,
                              productName: widget.product.name,
                              price: basePrice,
                              unit: widget.product.unit,
                              image: widget.product.imageUrl.isNotEmpty
                                  ? widget.product.imageUrl
                                  : productFallbackImage(
                                      widget.product.name,
                                      widget.product.category,
                                    ),
                              quantity: _totalQuantity,
                              stockQuantity: widget.product.stockQuantity,
                            );

                            await ref
                                .read(cartItemsProvider.notifier)
                                .addToCart(cartItem);

                            if (context.mounted) {
                              Navigator.pop(
                                context,
                                AddToCartResult.added,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() {
                                _isSubmitting = false;
                              });
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text('Could not add to cart: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF063A2F),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: const Color.fromRGBO(11, 55, 43, 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_cart_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add to Cart · ₱${_computedTotalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
    Color background = Colors.transparent,
    required Color foreground,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: foreground),
      ),
    );
  }
}
