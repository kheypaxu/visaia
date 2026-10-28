import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visaia/services/api_service.dart';
import 'package:visaia/widgets/explanation_loading.dart';

void main() {
  test(
    'detection returns before explanation and preserves job on disk roundtrip',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'qwen-result-test',
      );
      try {
        final image = await File(
          '${directory.path}/image.jpg',
        ).writeAsBytes([1, 2, 3]);
        final client = MockClient((request) async {
          expect(request.url.queryParameters['background'], 'true');
          return http.Response(
            jsonEncode({
              'pest': 'Fall Army Worm',
              'stages': ['larva'],
              'risk': 'High',
              'boxes': [],
              'analysis': '',
              'treatment': 'Fixed stage treatment',
              'explanation_id': 'job-123',
              'analysis_status': 'pending',
            }),
            200,
          );
        });
        final result = await ApiService.sendImage(image, client: client);
        expect(result.analysis, isEmpty);
        expect(result.treatment, 'Fixed stage treatment');
        final restored = AnalysisResult.fromJson(result.toJson());
        expect(restored.explanationId, 'job-123');
        expect(restored.analysisStatus, 'pending');
        client.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('status remains pending until the same job completes', () async {
    var calls = 0;
    final client = MockClient((request) async {
      expect(request.url.path, '/explanations/job-123');
      calls++;
      return http.Response(
        jsonEncode({
          'analysis_status': calls == 1 ? 'processing' : 'completed',
          'analysis': calls == 1 ? '' : 'Generated image explanation',
        }),
        200,
      );
    });
    expect(
      (await ApiService.fetchExplanation('job-123', client: client)).isFinished,
      isFalse,
    );
    final complete = await ApiService.fetchExplanation(
      'job-123',
      client: client,
    );
    expect(complete.isFinished, isTrue);
    expect(complete.analysis, 'Generated image explanation');
    client.close();
  });

  testWidgets('loading copy stays visible with reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ExplanationLoading()),
        ),
      ),
    );
    expect(find.text('Preparing your image explanation…'), findsOneWidget);
    await tester.pump(const Duration(minutes: 5));
    expect(
      find.textContaining('Your detection and treatment are ready.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading fits small portrait and landscape with large text', (
    tester,
  ) async {
    for (final size in [const Size(375, 812), const Size(812, 375)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(36),
                child: ExplanationLoading(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
