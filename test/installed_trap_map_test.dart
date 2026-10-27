import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/screens/logging_screens/installed_traps_screen.dart';
import 'package:visaia/screens/logging_screens/trap_lists.dart';

void main() {
  testWidgets(
    'review map recenters when draft placements arrive after loading',
    (tester) async {
      final trap = TrapItem(
        id: 'trap_1',
        name: 'Trap 1',
        zone: 'Field',
        position: const LatLng(14.5, 121),
        installationDate: DateTime(2026, 10, 1),
        nextLureDate: DateTime(2026, 11, 12),
        notes: '',
      );
      Widget view(List<TrapItem> traps) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: InstalledTrapMap(traps: traps, boundaries: const []),
          ),
        ),
      );
      await tester.pumpWidget(view([]));
      await tester.pumpWidget(view([trap]));
      await tester.pump();
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.mapController!.camera.center.latitude, closeTo(14.5, 0.00001));
      expect(map.mapController!.camera.center.longitude, closeTo(121, 0.00001));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('installed map exposes controls and opens the selected trap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trap = TrapItem(
      id: 'trap_1',
      name: 'Trap 1',
      zone: 'Field location',
      position: const LatLng(14.5, 121),
      installationDate: DateTime(2026, 10, 1),
      nextLureDate: DateTime(2026, 11, 12),
      notes: 'Near entrance',
    );
    TrapItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: InstalledTrapMap(
              traps: [trap],
              boundaries: const [],
              onInspect: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Show all traps'), findsOneWidget);
    expect(find.byTooltip('Open full map'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    await tester.tap(find.byTooltip('Show all traps'));
    await tester.pump();
    await tester.tap(find.byTooltip('Inspect Trap 1'));
    expect(selected, same(trap));
    selected = null;
    await tester.tap(find.byTooltip('Open full map'));
    await tester.pumpAndSettle();
    expect(find.text('Trap Locations'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byTooltip('Inspect Trap 1')));
    await tester.pumpAndSettle();
    expect(selected, same(trap));
    expect(find.text('Trap Locations'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
