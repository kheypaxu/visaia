import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shares the actual dashboard card rendering with the Android launcher.
class DashboardWidgetService {
  static const _channel = MethodChannel('visaia/dashboard_widget');
  static int _generation = 0;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static int beginSession() => ++_generation;

  static Future<void> update(Uint8List image, int generation) async {
    if (!supported || generation != _generation) return;
    try {
      await _channel.invokeMethod<void>('update', image);
    } on PlatformException catch (error) {
      debugPrint('Dashboard widget update failed: $error');
    } on MissingPluginException {
      // An older Android build may not have the native widget registered yet.
    }
  }

  static Future<void> clear() async {
    ++_generation;
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException catch (error) {
      debugPrint('Dashboard widget clear failed: $error');
    } on MissingPluginException {
      // Other platform builds do not provide a launcher widget.
    }
  }
}
