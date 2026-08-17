// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeliverySettings _$DeliverySettingsFromJson(Map<String, dynamic> json) =>
    _DeliverySettings(
      isAvailableToDeliver: json['isAvailableToDeliver'] as bool? ?? false,
      preferredThirdPartyBooking:
          json['preferredThirdPartyBooking'] as String? ?? 'none',
    );

Map<String, dynamic> _$DeliverySettingsToJson(_DeliverySettings instance) =>
    <String, dynamic>{
      'isAvailableToDeliver': instance.isAvailableToDeliver,
      'preferredThirdPartyBooking': instance.preferredThirdPartyBooking,
    };
