import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/screens/onboarding/farm_area_setup.dart';
import 'package:visaia/data/cabatuan_barangay_areas.dart';

void main() {
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FarmAreaSetup(onFinished: () {}, showTiles: false)),
    );
    await tester.pumpAndSettle();
  }

  Finder getSearch() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.hintText == 'Search barangay or location...',
  );
  MapController controller(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;

  testWidgets(
    'selecting a registration barangay zooms to its bounds and closes suggestions',
    (tester) async {
      await mount(tester);
      final originalZoom = controller(tester).camera.zoom;
      await tester.enterText(getSearch(), 'Acao');
      await tester.pump();
      expect(find.text('Acao, Cabatuan, Iloilo'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Acao'));
      await tester.pumpAndSettle();
      final area = cabatuanBarangayAreas['Acao']!;
      expect(
        controller(tester).camera.center.latitude,
        closeTo(area.center.latitude, .001),
      );
      expect(
        controller(tester).camera.center.longitude,
        closeTo(area.center.longitude, .001),
      );
      expect(controller(tester).camera.zoom, greaterThan(originalZoom));
      expect(find.byType(ListTile), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zone aliases work and keyboard Search submits a unique result', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(getSearch(), 'Barangay 10');
    await tester.pump();
    expect(find.text('Zone X Pob. (Barangay 10)'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final area = cabatuanBarangayAreas['Zone X Pob. (Barangay 10)']!;
    expect(
      controller(tester).camera.center.latitude,
      closeTo(area.center.latitude, .001),
    );
    expect(controller(tester).camera.zoom, greaterThan(14));
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown search explains alternatives and does not move the map', (
    tester,
  ) async {
    await mount(tester);
    final center = controller(tester).camera.center;
    await tester.enterText(getSearch(), 'unknown place');
    await tester.pump();
    expect(
      find.text(
        'No matching location. Try a Cabatuan barangay such as Acao, Tiring, or Zone 1.',
      ),
      findsOneWidget,
    );
    expect(controller(tester).camera.center, center);
    await tester.enterText(getSearch(), '');
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching preserves a drafted farm boundary', (tester) async {
    await mount(tester);
    await tester.tap(find.byIcon(Icons.add_location));
    await tester.pump();
    // Seed the draft through the map callback; this test disables tile hit areas.
    for (final point in [
      const LatLng(10.88, 122.48),
      const LatLng(10.881, 122.48),
      const LatLng(10.88, 122.481),
    ]) {
      tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
        const TapPosition(Offset.zero, Offset.zero), point);
      await tester.pump();
    }
    final before = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .map((m) => m.point)
        .toList();
    expect(before.length, 3);
    await tester.enterText(getSearch(), 'Tiring');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'Tiring'));
    await tester.pumpAndSettle();
    final after = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .map((m) => m.point)
        .toList();
    expect(after, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search results remain tappable on a phone with the keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await mount(tester);
      await tester.enterText(getSearch(), 'Acao');
      await tester.pump();
      expect(
        find.widgetWithText(ListTile, 'Acao').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Acao'));
      await tester.pumpAndSettle();
      expect(
        controller(tester).camera.center.latitude,
        closeTo(cabatuanBarangayAreas['Acao']!.center.latitude, .001),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
