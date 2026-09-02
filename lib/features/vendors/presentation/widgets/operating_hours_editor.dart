import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/vendors/domain/day_schedule.dart';

class OperatingHoursEditor extends StatefulWidget {
  final List<DaySchedule> schedules;

  /// Copies the schedule of the day at [index] to every other day.
  /// Invoked when the vendor confirms "Apply to all days" after editing.
  final ValueChanged<int> onApplyDayToAll;
  final VoidCallback onChanged;

  const OperatingHoursEditor({
    super.key,
    required this.schedules,
    required this.onApplyDayToAll,
    required this.onChanged,
  });

  @override
  State<OperatingHoursEditor> createState() => _OperatingHoursEditorState();
}

class _OperatingHoursEditorState extends State<OperatingHoursEditor> {
  bool _isExpanded = false;

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _timeToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _stringToTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return const TimeOfDay(hour: 6, minute: 0);
  }

  Future<void> _selectTime(
    BuildContext context,
    int index,
    bool isOpenTime,
  ) async {
    final schedule = widget.schedules[index];
    final timeStr = isOpenTime ? schedule.openTime : schedule.closeTime;
    final initialTime = _stringToTime(timeStr);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppTheme.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final formatted = _timeToString(picked);
      if (isOpenTime) {
        widget.schedules[index] = schedule.copyWith(openTime: formatted);
      } else {
        widget.schedules[index] = schedule.copyWith(closeTime: formatted);
      }
      widget.onChanged();
      _promptApplyToAll(index);
    }
  }

  /// Asked after any single-day edit: copy this day's schedule to the rest?
  Future<void> _promptApplyToAll(int index) async {
    if (!mounted) return;
    final dayName = widget.schedules[index].name;
    final applyToAll = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: const Text(
          'Apply to all days?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          "Apply $dayName's schedule to all other days?",
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text(
              'Only this day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            child: const Text(
              'Apply to all days',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (applyToAll == true && mounted) {
      widget.onApplyDayToAll(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Operating Hours',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          ...List.generate(widget.schedules.length, (index) {
            final schedule = widget.schedules[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      schedule.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: schedule.isOpen
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => _selectTime(context, index, true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Text(
                                    _formatTime(
                                      _stringToTime(schedule.openTime),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '-',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _selectTime(context, index, false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Text(
                                    _formatTime(
                                      _stringToTime(schedule.closeTime),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Closed',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.muted,
                            ),
                          ),
                  ),
                  Switch(
                    value: schedule.isOpen,
                    onChanged: (val) {
                      widget.schedules[index] = schedule.copyWith(isOpen: val);
                      widget.onChanged();
                      _promptApplyToAll(index);
                    },
                    activeThumbColor: AppTheme.primaryGreen,
                    activeTrackColor: AppTheme.primaryGreen.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
