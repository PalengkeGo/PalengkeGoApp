import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery_settings.freezed.dart';
part 'delivery_settings.g.dart';

@freezed
abstract class DeliverySettings with _$DeliverySettings {
  const factory DeliverySettings({
    @Default(false) bool isAvailableToDeliver,

    /// e.g., 'lalamove', 'grabexpress', or 'none'
    @Default('none') String preferredThirdPartyBooking,
  }) = _DeliverySettings;

  factory DeliverySettings.fromJson(Map<String, dynamic> json) =>
      _$DeliverySettingsFromJson(json);
}
