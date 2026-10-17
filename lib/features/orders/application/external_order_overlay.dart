import 'package:flutter/services.dart';

typedef ExternalOrderOverlayOpenHandler = Future<void> Function();

class ExternalOrderOverlay {
  static const _channel = MethodChannel('palengkego/order_overlay');

  static void setOpenHandler(ExternalOrderOverlayOpenHandler? handler) {
    _channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == 'openActiveOrders') await handler();
            },
    );
  }

  static Future<bool> canDrawOverlays() async {
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      // Unsupported platform or a widget-test binding without the native host.
    } on PlatformException {
      // The overlay settings screen may be unavailable on this device.
    }
  }

  static Future<void> show(int activeOrderCount) async {
    try {
      await _channel.invokeMethod<void>('show', {'count': activeOrderCount});
    } on MissingPluginException {
      // Unsupported platform or a widget-test binding without the native host.
    } on PlatformException {
      // Ignore devices where system overlay access is unavailable.
    }
  }

  static Future<void> hide() async {
    try {
      await _channel.invokeMethod<void>('hide');
    } on MissingPluginException {
      // Unsupported platform or a widget-test binding without the native host.
    } on PlatformException {
      // The overlay may already have been removed by Android.
    }
  }
}
