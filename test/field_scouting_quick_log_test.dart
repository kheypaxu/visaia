import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/logging_screens/field_scouting_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final fonts = <String, dynamic>{
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ])
        'assets/fonts/Inter-$weight.ttf': [
          {'asset': 'assets/fonts/Inter-$weight.ttf'},
        ],
    };
    final manifest = const StandardMessageCodec().encodeMessage(fonts)!;
    final font = ByteData.sublistView(
      File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin') return manifest;
          if (key.startsWith('assets/fonts/Inter-')) return font;
          final file = File(key);
          return file.existsSync()
              ? ByteData.sublistView(file.readAsBytesSync())
              : null;
        });
  });

  testWidgets(
    'Quick Log keeps original header and both selectors in one form',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: FieldScoutingFormScreen(userId: 'test-user')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text('Select Growth Cycle'), findsOneWidget);
      expect(find.text('STATION SELECTION'), findsOneWidget);
      expect(find.text('Station 1'), findsOneWidget);
      expect(find.text('Save Scouting Data'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('FIELD PHOTO'), findsOneWidget);
      expect(find.text('Moths'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
