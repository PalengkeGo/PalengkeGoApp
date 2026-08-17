// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DaySchedule _$DayScheduleFromJson(Map<String, dynamic> json) => _DaySchedule(
  name: json['name'] as String,
  isOpen: json['isOpen'] as bool? ?? true,
  openTime: json['openTime'] as String? ?? "06:00",
  closeTime: json['closeTime'] as String? ?? "18:00",
);

Map<String, dynamic> _$DayScheduleToJson(_DaySchedule instance) =>
    <String, dynamic>{
      'name': instance.name,
      'isOpen': instance.isOpen,
      'openTime': instance.openTime,
      'closeTime': instance.closeTime,
    };
