import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/vendors/domain/day_schedule.dart';

class OperatingHoursEditor extends StatefulWidget {
  final List<DaySchedule> schedules;
  final VoidCallback onApplyMondayToAll;
  final VoidCallback onChanged;

  const OperatingHoursEditor({
    super.key,
    required this.schedules,
    required this.onApplyMondayToAll,
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

    if (picked != null) {
      final formatted = _timeToString(picked);
      if (isOpenTime) {
        widget.schedules[index] = schedule.copyWith(openTime: formatted);
      } else {
        widget.schedules[index] = schedule.copyWith(closeTime: formatted);
      }
      widget.onChanged();
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
                if (_isExpanded)
                  TextButton.icon(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppTheme.primaryGreen,
                    ),
                    label: const Text(
                      'Apply Mon to All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    onPressed: widget.onApplyMondayToAll,
                  ),
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
