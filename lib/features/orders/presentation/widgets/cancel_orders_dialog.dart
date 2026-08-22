import 'package:palengkego/core/utils/money.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';

/// Multi-select dialog for cancelling several active orders at once.
class CancelOrdersDialog extends StatefulWidget {
  final List<MarketOrder> activeOrders;
  final String currentOrderId;

  const CancelOrdersDialog({
    super.key,
    required this.activeOrders,
    required this.currentOrderId,
  });

  @override
  State<CancelOrdersDialog> createState() => _CancelOrdersDialogState();
}

class _CancelOrdersDialogState extends State<CancelOrdersDialog> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _selectedIds.add(widget.currentOrderId);
  }

  void _toggleAll() {
    setState(() {
      if (_selectedIds.length == widget.activeOrders.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(widget.activeOrders.map((o) => o.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedIds.length == widget.activeOrders.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Cancel Orders',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select the active orders you wish to cancel. This action cannot be undone.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select All',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Checkbox(
                  value: allSelected,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (_) => _toggleAll(),
                ),
              ],
            ),
            const Divider(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.activeOrders.length,
                itemBuilder: (context, index) {
                  final order = widget.activeOrders[index];
                  final isSelected = _selectedIds.contains(order.id);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                    activeColor: AppTheme.primaryGreen,
                    title: Text(
                      order.vendorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Order ${order.id} • ${pesoOf(order.total)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(order.id);
                        } else {
                          _selectedIds.remove(order.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIds.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            disabledBackgroundColor: const Color(
              0xFFDC2626,
            ).withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Confirm',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
