import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String? _selectedWeight;
  double _customWeightKg = 1.0;
  bool _isSubmitting = false;
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    final isPiece = _isPieceProduct();
    final u = widget.product.unit.trim();
    final unitStr = u.isEmpty ? 'pc' : u;
    _weights = isPiece
        ? ['1 $unitStr', '2 $unitStr', '3 $unitStr', '5 $unitStr']
        : ['1/4 kg', '1/2 kg', '3/4 kg', '1 kg'];
    _selectedWeight = null;
    _customWeightKg = isPiece ? 1.0 : 0.25;
    _qtyController = TextEditingController(
      text: isPiece ? '1' : _formatCustomWeightNum(_customWeightKg),
    );
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

  @override
  Widget build(BuildContext context) {
    final basePrice = widget.product.discountedPrice;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.25),
            offset: Offset(0, -4),
            blurRadius: 4,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 30,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 107,
                      height: 99,
                      child: widget.product.imageUrl.isNotEmpty
                          ? AdaptiveImage(
                              widget.product.imageUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(
                                Icons.image_rounded,
                                size: 28,
                                color: AppTheme.muted,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _priceLabel(basePrice),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stock: ${widget.product.stockQuantity % 1 == 0 ? widget.product.stockQuantity.toInt().toString() : widget.product.stockQuantity.toStringAsFixed(2)} ${widget.product.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.product.isLowStock
                                  ? const Color(0xFFDC2626)
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          if (widget.product.isLowStock) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: const Text(
                                'Low Stock Warning',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _weights.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _weights.length <= 2 ? 2 : 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 18,
                  childAspectRatio: 2.32,
                ),
                itemBuilder: (context, index) {
                  final weightLabel = _weights[index];
                  final isSelected = weightLabel == _selectedWeight;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedWeight = weightLabel;
                        if (_isPieceProduct()) {
                          final pieceCounts = [1.0, 2.0, 3.0, 5.0];
                          _customWeightKg = index < pieceCounts.length
                              ? pieceCounts[index]
                              : 1.0;
                          _qtyController.text = _customWeightKg
                              .toInt()
                              .toString();
                        } else {
                          if (weightLabel == '1 kg') {
                            _customWeightKg = 1.0;
                          } else if (weightLabel == '3/4 kg') {
                            _customWeightKg = 0.75;
                          } else if (weightLabel == '1/2 kg') {
                            _customWeightKg = 0.5;
                          } else if (weightLabel == '1/4 kg') {
                            _customWeightKg = 0.25;
                          }
                          _qtyController.text = _formatCustomWeightNum(
                            _customWeightKg,
                          );
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0C3A2D)
                            : const Color(0xFFF1F5F4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0C3A2D)
                              : const Color(0xFFF3F4F6),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        weightLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF0C3A2D),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F2),
                      border: Border.all(color: const Color(0xFFE5E7E6)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roundQuantityButton(
                          icon: Icons.remove_rounded,
                          onTap: () {
                            if (_isPieceProduct()) {
                              if (_customWeightKg > 1.0) {
                                setState(() {
                                  _customWeightKg -= 1.0;
                                  _selectedWeight = null;
                                  _qtyController.text = _customWeightKg
                                      .toInt()
                                      .toString();
                                });
                              }
                            } else {
                              if (_customWeightKg > 0.125) {
                                setState(() {
                                  _customWeightKg = _stepKgQuantity(
                                    _customWeightKg,
                                    false,
                                    widget.product.stockQuantity,
                                  );
                                  _selectedWeight = null;
                                  _qtyController.text = _formatCustomWeightNum(
                                    _customWeightKg,
                                  );
                                });
                              }
                            }
                          },
                          foreground:
                              _customWeightKg >
                                  (_isPieceProduct() ? 1.0 : 0.125)
                              ? AppTheme.accentGreen
                              : AppTheme.muted,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _qtyController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\./]'),
                                ),
                              ],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                final parsed = _parseQuantityString(val);
                                if (parsed != null && parsed > 0) {
                                  setState(() {
                                    _customWeightKg = parsed;
                                    _selectedWeight = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            _isPieceProduct() ? 'pc' : 'kg',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                        _roundQuantityButton(
                          icon: Icons.add_rounded,
                          onTap: () {
                            if (_customWeightKg <
                                widget.product.stockQuantity) {
                              setState(() {
                                if (_isPieceProduct()) {
                                  _customWeightKg += 1.0;
                                  _qtyController.text = _customWeightKg
                                      .toInt()
                                      .toString();
                                } else {
                                  _customWeightKg = _stepKgQuantity(
                                    _customWeightKg,
                                    true,
                                    widget.product.stockQuantity,
                                  );
                                  _qtyController.text = _formatCustomWeightNum(
                                    _customWeightKg,
                                  );
                                }
                                _selectedWeight = null;
                              });
                            } else {
                              if (!mounted) return;
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                const SnackBar(
                                  content: Text('Maximum stock reached'),
                                ),
                              );
                            }
                          },
                          background: const Color(0xFF0C3A2D),
                          foreground: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      (_isSubmitting || widget.product.stockQuantity <= 0)
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

                          setState(() {
                            _isSubmitting = true;
                          });

                          final needLogin = await ref
                              .read(cartItemsProvider.notifier)
                              .addFirstItemPromptingLogin(
                                CartItem(
                                  productId: widget.product.id,
                                  vendorName: widget.vendorName,
                                  productName: widget.product.name,
                                  price: basePrice,
                                  unit: widget.product.unit,
                                  image: widget.product.imageUrl.isNotEmpty
                                      ? widget.product.imageUrl
                                      : '',
                                  quantity: _customWeightKg,
                                  stockQuantity: widget.product.stockQuantity,
                                ),
                              );

                          if (context.mounted) {
                            Navigator.pop(
                              context,
                              needLogin
                                  ? AddToCartResult.addedLoginRequired
                                  : AddToCartResult.added,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C3A2D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: const Color.fromRGBO(11, 55, 43, 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    'Add to cart',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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

  double _stepKgQuantity(double current, bool isIncrement, double maxWeight) {
    final double whole = current.floorToDouble();
    final double fraction = current - whole;

    if (isIncrement) {
      if (fraction < 0.124) {
        return (whole + 0.125).clamp(0.125, maxWeight);
      } else if (fraction < 0.249) {
        return (whole + 0.25).clamp(0.125, maxWeight);
      } else if (fraction < 0.499) {
        return (whole + 0.5).clamp(0.125, maxWeight);
      } else if (fraction < 0.749) {
        return (whole + 0.75).clamp(0.125, maxWeight);
      } else {
        return (whole + 1.0).clamp(0.125, maxWeight);
      }
    } else {
      if (fraction > 0.751) {
        return (whole + 0.75).clamp(0.125, maxWeight);
      } else if (fraction > 0.501) {
        return (whole + 0.5).clamp(0.125, maxWeight);
      } else if (fraction > 0.251) {
        return (whole + 0.25).clamp(0.125, maxWeight);
      } else if (fraction > 0.126) {
        return (whole + 0.125).clamp(0.125, maxWeight);
      } else if (fraction > 0.001) {
        return whole.clamp(0.125, maxWeight);
      } else {
        if (whole >= 1.0) {
          return (whole - 1.0 + 0.75).clamp(0.125, maxWeight);
        } else {
          return 0.125;
        }
      }
    }
  }

  double? _parseQuantityString(String val) {
    val = val.trim();
    if (val.isEmpty) return null;
    final direct = double.tryParse(val);
    if (direct != null) return direct;

    if (val.contains(' ')) {
      final parts = val.split(RegExp(r'\s+'));
      if (parts.length == 2) {
        final whole = double.tryParse(parts[0]);
        final frac = _parseSimpleFraction(parts[1]);
        if (whole != null && frac != null) {
          return whole + frac;
        }
      }
    }
    return _parseSimpleFraction(val);
  }

  double? _parseSimpleFraction(String val) {
    if (val.contains('/')) {
      final parts = val.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den != 0) {
          return num / den;
        }
      }
    }
    return null;
  }

  String _formatCustomWeightNum(double val) {
    if (val <= 0) return '0';
    final int whole = val.truncate();
    final double fraction = (val - whole).abs();

    String fracStr = '';
    if ((fraction - 0.125).abs() < 0.005) {
      fracStr = '1/8';
    } else if ((fraction - 0.25).abs() < 0.005) {
      fracStr = '1/4';
    } else if ((fraction - 0.375).abs() < 0.005) {
      fracStr = '3/8';
    } else if ((fraction - 0.5).abs() < 0.005) {
      fracStr = '1/2';
    } else if ((fraction - 0.625).abs() < 0.005) {
      fracStr = '5/8';
    } else if ((fraction - 0.75).abs() < 0.005) {
      fracStr = '3/4';
    } else if ((fraction - 0.875).abs() < 0.005) {
      fracStr = '7/8';
    } else if (fraction > 0.01) {
      fracStr = fraction
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0*$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    if (whole == 0) {
      return fracStr.isNotEmpty ? fracStr : '0';
    } else {
      return fracStr.isNotEmpty ? '$whole $fracStr' : whole.toString();
    }
  }

  String _priceLabel(double basePrice) {
    final unit = _isPieceProduct() ? 'pc' : 'kg';
    return '₱${basePrice.toStringAsFixed(2)}/$unit';
  }
}
