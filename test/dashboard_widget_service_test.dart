import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/dashboard_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('visaia/dashboard_widget');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('publishes the current dashboard image to Android', () async {
    final session = DashboardWidgetService.beginSession();
    await DashboardWidgetService.update(Uint8List.fromList([1, 2, 3]), session);
    expect(calls.single.method, 'update');
    expect(calls.single.arguments, orderedEquals([1, 2, 3]));
  });

  test(
    'logout clears the image and rejects an in-flight old capture',
    () async {
      final session = DashboardWidgetService.beginSession();
      await DashboardWidgetService.clear();
      await DashboardWidgetService.update(Uint8List(0), session);
      expect(calls.map((call) => call.method), ['clear']);
    },
  );

  test('farm changes reject the previous farm image', () async {
    final oldSession = DashboardWidgetService.beginSession();
    final newSession = DashboardWidgetService.beginSession();
    await DashboardWidgetService.update(Uint8List(0), oldSession);
    await DashboardWidgetService.update(Uint8List(0), newSession);
    expect(calls.length, 1);
  });

  test('other platforms skip the Android channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final session = DashboardWidgetService.beginSession();
    await DashboardWidgetService.update(Uint8List(0), session);
    await DashboardWidgetService.clear();
    expect(calls, isEmpty);
  });
}
