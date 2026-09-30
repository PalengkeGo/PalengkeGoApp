import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/domain/day_schedule.dart';
import 'package:palengkego/features/vendors/domain/closing_time.dart';

// One shared read for visible stalls, refreshed with the existing market signal.
final marketSchedulesProvider =
    FutureProvider.autoDispose<Map<String, List<DaySchedule>>>((ref) async {
      ref.watch(dataRefreshSignal);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) {
        final stall = ref.watch(vendorStallProvider);
        return {stall.stallId: stall.schedule};
      }
      final rows = await client
          .from('stall_holder_schedule')
          .select(
            'stall_holder_id,day_of_week,is_closed,opening_time,closing_time',
          );
      final schedules = <String, List<DaySchedule>>{};
      for (final row in rows) {
        final id = row['stall_holder_id'] as String;
        schedules
            .putIfAbsent(id, () => [])
            .add(
              DaySchedule(
                name: row['day_of_week'] as String,
                isOpen: row['is_closed'] != true,
                openTime: row['opening_time'] as String? ?? '',
                closeTime: row['closing_time'] as String? ?? '',
              ),
            );
      }
      return schedules;
    });

final closingClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 15), (_) => DateTime.now());
});

class ClosingSoonNotice extends ConsumerWidget {
  const ClosingSoonNotice({
    super.key,
    required this.vendorId,
    required this.isOpen,
  });
  final String vendorId;
  final bool isOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isOpen) return const SizedBox.shrink();
    final schedules = ref.watch(marketSchedulesProvider).value;
    final now = ref.watch(closingClockProvider).value ?? DateTime.now();
    final minutes = minutesUntilClosing(
      schedules?[vendorId] ?? [],
      now,
      isOpen: isOpen,
    );
    if (minutes == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Closes in $minutes min',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF714500),
        ),
      ),
    );
  }
}
