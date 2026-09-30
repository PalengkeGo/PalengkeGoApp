import 'day_schedule.dart';

/// Saved market hours are Philippine time, regardless of the customer's timezone.
int? minutesUntilClosing(
  List<DaySchedule> schedule,
  DateTime now, {
  required bool isOpen,
}) {
  if (!isOpen) return null;
  final local = now.toUtc().add(const Duration(hours: 8));
  final midnight = DateTime.utc(local.year, local.month, local.day);
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  int? parseTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})(?::00)?$').firstMatch(value);
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    return hour < 24 && minute < 60 ? hour * 60 + minute : null;
  }

  // Yesterday covers an overnight shift ending this morning.
  for (final offset in [0, -1]) {
    final date = midnight.add(Duration(days: offset));
    for (final day in schedule.where(
      (d) => d.name == days[date.weekday - 1] && d.isOpen,
    )) {
      final start = parseTime(day.openTime);
      final end = parseTime(day.closeTime);
      if (start == null || end == null || start == end) continue;
      final opens = date.add(Duration(minutes: start));
      final closes = date.add(
        Duration(minutes: end + (end < start ? 1440 : 0)),
      );
      if (local.isBefore(opens) || !local.isBefore(closes)) continue;
      final remaining = closes.difference(local);
      if (remaining <= const Duration(hours: 1)) {
        return (remaining.inMilliseconds / Duration.millisecondsPerMinute)
            .ceil();
      }
    }
  }
  return null;
}
