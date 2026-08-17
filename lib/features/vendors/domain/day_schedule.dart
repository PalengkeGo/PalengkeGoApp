import 'package:freezed_annotation/freezed_annotation.dart';

part 'day_schedule.freezed.dart';
part 'day_schedule.g.dart';

@freezed
abstract class DaySchedule with _$DaySchedule {
  const factory DaySchedule({
    required String name,
    @Default(true) bool isOpen,

    /// Store as string "HH:mm" for easy JSON serialization in Firestore
    @Default("06:00") String openTime,
    @Default("18:00") String closeTime,
  }) = _DaySchedule;

  factory DaySchedule.fromJson(Map<String, dynamic> json) =>
      _$DayScheduleFromJson(json);
}
