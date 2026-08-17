import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

class OrderDetailsTimeline extends StatelessWidget {
  const OrderDetailsTimeline({
    super.key,
    required this.currentStatus,
    required this.isPickup,
  });

  final OrderStatus currentStatus;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final steps = _stepsFor(currentStatus, isPickup: isPickup);

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = step.state == _TimelineStepState.completed;
        final isActive = step.state == _TimelineStepState.active;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted || isActive
                        ? AppTheme.primaryGreen
                        : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : isActive
                      ? const Icon(
                          Icons.more_horiz_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted
                        ? AppTheme.primaryGreen
                        : const Color(0xFFE5E7EB),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCompleted || isActive
                          ? AppTheme.textPrimary
                          : AppTheme.muted,
                    ),
                  ),
                  if (step.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: isCompleted
                            ? AppTheme.textSecondary
                            : isActive
                            ? AppTheme.primaryGreen
                            : AppTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  List<_TimelineStep> _stepsFor(OrderStatus status, {required bool isPickup}) {
    final travelLabel = isPickup ? 'Ready for Pick-Up' : 'Out for Delivery';
    final travelSubtitle = isPickup
        ? 'Head to the stall holder stall'
        : 'Rider is heading your way';

    if (status == OrderStatus.cancelled) {
      return const [
        _TimelineStep.completed('Order Placed', 'Order was submitted'),
        _TimelineStep.active('Cancelled', 'This order has been cancelled'),
        _TimelineStep.pending('Preparing', ''),
        _TimelineStep.pending('Completed', ''),
      ];
    }

    return [
      const _TimelineStep.completed('Order Placed', 'Order was submitted'),
      _TimelineStep(
        label: 'Stall Holder Confirmation',
        subtitle: 'Waiting for stall holder confirmation',
        state: status == OrderStatus.pending
            ? _TimelineStepState.active
            : _TimelineStepState.completed,
      ),
      _TimelineStep(
        label: 'Preparing',
        subtitle: 'Stall Holder is preparing your items',
        state: _stateFor(status, active: OrderStatus.preparing),
      ),
      _TimelineStep(
        label: travelLabel,
        subtitle: travelSubtitle,
        state: _stateFor(status, active: OrderStatus.ready),
      ),
      _TimelineStep(
        label: 'Completed',
        subtitle: 'Order completed',
        state: status == OrderStatus.completed
            ? _TimelineStepState.completed
            : _TimelineStepState.pending,
      ),
    ];
  }

  _TimelineStepState _stateFor(
    OrderStatus status, {
    required OrderStatus active,
  }) {
    if (status == active) {
      return _TimelineStepState.active;
    }

    final rank = {
      OrderStatus.pending: 0,
      OrderStatus.confirmed: 1,
      OrderStatus.preparing: 2,
      OrderStatus.ready: 3,
      OrderStatus.completed: 4,
      OrderStatus.cancelled: -1,
    };

    return rank[status]! > rank[active]!
        ? _TimelineStepState.completed
        : _TimelineStepState.pending;
  }
}

enum _TimelineStepState { completed, active, pending }

class _TimelineStep {
  const _TimelineStep({
    required this.label,
    required this.subtitle,
    required this.state,
  });

  const _TimelineStep.completed(String label, String subtitle)
    : this(
        label: label,
        subtitle: subtitle,
        state: _TimelineStepState.completed,
      );

  const _TimelineStep.active(String label, String subtitle)
    : this(label: label, subtitle: subtitle, state: _TimelineStepState.active);

  const _TimelineStep.pending(String label, String subtitle)
    : this(label: label, subtitle: subtitle, state: _TimelineStepState.pending);

  final String label;
  final String subtitle;
  final _TimelineStepState state;
}
