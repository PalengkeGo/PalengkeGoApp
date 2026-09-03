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
    final isAllDone = currentStatus == OrderStatus.completed;

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = step.state == _TimelineStepState.completed;
        final isActive = step.state == _TimelineStepState.active;
        final isLast = index == steps.length - 1;

        BoxDecoration circleDecoration;
        Widget? circleChild;

        if (isAllDone) {
          // When order is fully completed, all steps have solid green fill and white check
          circleDecoration = const BoxDecoration(
            color: AppTheme.primaryGreen,
            shape: BoxShape.circle,
          );
          circleChild = const Icon(Icons.check, size: 14, color: Colors.white);
        } else {
          // While order is in progress, no circle has green fill; only circle outlines
          if (isCompleted) {
            circleDecoration = BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryGreen, width: 2),
            );
            circleChild = const Icon(
              Icons.check,
              size: 14,
              color: AppTheme.primaryGreen,
            );
          } else if (isActive) {
            circleDecoration = BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryGreen, width: 2),
            );
            circleChild = null; // Clean circle outline showing destination in-progress
          } else {
            circleDecoration = BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            );
            circleChild = null;
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: circleDecoration,
                  child: circleChild,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted || isAllDone
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
    if (status == active ||
        (active == OrderStatus.ready &&
            status == OrderStatus.outForDelivery)) {
      return _TimelineStepState.active;
    }

    final rank = {
      OrderStatus.pending: 0,
      OrderStatus.confirmed: 1,
      OrderStatus.preparing: 2,
      OrderStatus.ready: 3,
      OrderStatus.outForDelivery: 3,
      OrderStatus.completed: 4,
      OrderStatus.cancelled: -1,
      OrderStatus.rejected: -1,
    };

    final currentRank = rank[status] ?? 0;
    final activeRank = rank[active] ?? 0;

    return currentRank > activeRank
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
