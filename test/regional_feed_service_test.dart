import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/regional_feed_service.dart';
import 'package:visaia/services/faw_activity_service.dart';
import 'package:visaia/services/faw_risk_service.dart';
import 'package:visaia/services/detection_weather_service.dart';

Map<String, dynamic> payload(DateTime now, {String id = 'a'}) => {
  'schemaVersion': 1,
  'municipality': 'Cabatuan',
  'generatedAt': now.toIso8601String(),
  'assessment': [
    {
      'stage': 'moth',
      'total': 2,
      'findings': [
        {
          'barangay': 'Acao',
          'count': 2,
          'growthStages': ['Early Vegetative'],
        },
      ],
    },
  ],
  'threats': [
    {
      'id': List.filled(64, id).join(),
      'isClustered': true,
      'location': {'lat': 10.8, 'lng': 122.4},
      'barangay': 'Acao',
      'stage': 'moth',
      'risk': 'High',
      'dap': 25,
      'counts': {'egg': 0, 'larva': 0, 'pupa': 0, 'moth': 2},
      'damagePercentage': 0,
      'thresholdReached': false,
      'timestamp': now.toIso8601String(),
    },
  ],
};

class NoNetworkWeather extends DetectionWeatherService {
  @override
  Future<List<DetectionWeather?>> fetchBatch(
    List<({double lat, double lng, DateTime date})> items, {
    int concurrency = 4,
  }) async => List.filled(items.length, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 24, 2);

  test('only public fields are retained in the decoded model', () {
    final raw = payload(now);
    raw['privateIdentity'] = 'PRIVATE';
    (raw['threats'] as List).first['farmerName'] = 'PRIVATE';
    final parsed = RegionalFeedSnapshot.fromJson(raw);
    expect(jsonEncode(parsed.threats), isNot(contains('PRIVATE')));
    expect(parsed.threats.single['barangay'], 'Acao');
    final assessment = assessmentFromSnapshot(parsed);
    expect(assessment.single.total, 2);
    expect(assessment.single.stage, FawLifeStage.moth);
  });
  test(
    'a real empty successful response remains distinguishable from failure',
    () {
      final parsed = RegionalFeedSnapshot.fromJson({
        ...payload(now),
        'assessment': [],
        'threats': [],
      });
      expect(parsed.threats, isEmpty);
      expect(parsed.assessment, isEmpty);
    },
  );
  test(
    'malformed totals, private labels and invalid coordinates are rejected',
    () {
      final wrongTotal = payload(now);
      wrongTotal['assessment'][0]['total'] = 999;
      expect(
        () => RegionalFeedSnapshot.fromJson(wrongTotal),
        throwsA(isA<RegionalFeedException>()),
      );
      final privateLabel = payload(now);
      privateLabel['threats'][0]['barangay'] = 'PRIVATE FARM ADDRESS';
      expect(
        () => RegionalFeedSnapshot.fromJson(privateLabel),
        throwsA(isA<RegionalFeedException>()),
      );
      final badLocation = payload(now);
      badLocation['threats'][0]['location']['lat'] = 200.0;
      expect(
        () => RegionalFeedSnapshot.fromJson(badLocation),
        throwsA(isA<RegionalFeedException>()),
      );
    },
  );
  test(
    'HTTP request uses an ID token header and coalesces map and assessment loads',
    () async {
      var calls = 0;
      final client = RegionalFeedClient(
        currentUid: () => 'farmer-a',
        token: () async => 'secret-token',
        now: () => now,
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/mobile/regional-risk');
          expect(request.url.toString(), isNot(contains('secret-token')));
          expect(request.headers['Authorization'], 'Bearer secret-token');
          return http.Response(jsonEncode(payload(now)), 200);
        }),
      );
      final values = await Future.wait([client.load(), client.load()]);
      expect(calls, 1);
      expect(identical(values.first, values.last), isTrue);
    },
  );
  test(
    'caches are separated by account and do not fetch another account response',
    () async {
      var uid = 'farmer-a';
      var calls = 0;
      final client = RegionalFeedClient(
        currentUid: () => uid,
        token: () async => 'token',
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode(payload(now, id: uid == 'farmer-a' ? 'a' : 'b')),
            200,
          );
        }),
      );
      expect((await client.load()).threats.single['id'], 'a' * 64);
      uid = 'farmer-b';
      expect((await client.load()).threats.single['id'], 'b' * 64);
      uid = 'farmer-a';
      expect((await client.load()).threats.single['id'], 'a' * 64);
      expect(calls, 2);
    },
  );
  test('an in-flight result from a previous account is discarded', () async {
    var uid = 'farmer-a';
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    final client = RegionalFeedClient(
      currentUid: () => uid,
      token: () async => 'token',
      now: () => now,
      client: MockClient((_) {
        started.complete();
        return gate.future;
      }),
    );
    final request = client.load();
    final rejected = expectLater(
      request,
      throwsA(isA<RegionalFeedException>()),
    );
    await started.future;
    uid = 'farmer-b';
    gate.complete(http.Response(jsonEncode(payload(now)), 200));
    await rejected;
  });
  test('expired local data causes a new authenticated request', () async {
    var clock = now;
    var calls = 0;
    final client = RegionalFeedClient(
      currentUid: () => 'farmer-a',
      token: () async => 'token',
      now: () => clock,
      client: MockClient((_) async {
        calls++;
        return http.Response(jsonEncode(payload(clock)), 200);
      }),
    );
    await client.load();
    clock = now.add(const Duration(minutes: 6));
    await client.load();
    expect(calls, 2);
  });
  test(
    'forbidden and unavailable responses throw instead of returning no-risk data',
    () async {
      for (final status in [401, 403, 503]) {
        final client = RegionalFeedClient(
          currentUid: () => 'farmer-a',
          token: () async => 'token',
          now: () => now,
          client: MockClient((_) async => http.Response('{}', status)),
        );
        await expectLater(client.load(), throwsA(isA<RegionalFeedException>()));
      }
    },
  );
  test('failed requests are not cached and can be retried', () async {
    var calls = 0;
    final client = RegionalFeedClient(
      currentUid: () => 'farmer-a',
      token: () async => 'token',
      now: () => now,
      client: MockClient(
        (_) async => ++calls == 1
            ? http.Response('{}', 503)
            : http.Response(jsonEncode(payload(now)), 200),
      ),
    );
    await expectLater(client.load(), throwsA(isA<RegionalFeedException>()));
    expect((await client.load()).assessment, isNotEmpty);
    expect(calls, 2);
  });
  test(
    'offline/incorrect account cannot request another account regional view',
    () async {
      var calls = 0;
      final client = RegionalFeedClient(
        currentUid: () => 'farmer-a',
        token: () async => 'token',
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        client.load(expectedUserId: 'farmer-b'),
        throwsA(isA<RegionalFeedException>()),
      );
      expect(calls, 0);
    },
  );
  test('regional polling waits while backgrounded and refreshes after resume', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    var clock = now;
    var calls = 0;
    final first = Completer<void>();
    final second = Completer<void>();
    var received = 0;
    final client = RegionalFeedClient(currentUid: () => 'farmer-a', token: () async => 'token', now: () => clock,
      client: MockClient((_) async { calls++; return http.Response(jsonEncode(payload(clock)), 200); }));
    final subscription = client.watch().listen((_) {
      received++;
      if (received == 1) first.complete();
      if (received == 2) second.complete();
    });
    try {
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await first.future.timeout(const Duration(seconds: 2));
      expect(calls, 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock = now.add(const Duration(minutes: 10));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await second.future.timeout(const Duration(seconds: 2));
      expect(calls, 2);
    } finally {
      await subscription.cancel().timeout(const Duration(seconds: 2));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });
  test(
    'nearby threats use the same wind/distance engine without Firebase or raw identity reads',
    () async {
      final client = RegionalFeedClient(
        currentUid: () => 'farmer-a',
        token: () async => 'token',
        now: () => now,
        client: MockClient(
          (_) async => http.Response(jsonEncode(payload(now)), 200),
        ),
      );
      final service = FawRiskService(
        feedClient: client,
        weatherService: NoNetworkWeather(),
      );
      final threats = await service.loadMothThreats(
        currentUserId: 'farmer-a',
        anchors: [const LatLng(10.8001, 122.4)],
      );
      expect(threats, hasLength(1));
      expect(threats.single.isExternal, isTrue);
      expect(threats.single.ownerId, isEmpty);
      expect(threats.single.farmerName, isEmpty);
      expect(threats.single.farmName, isEmpty);
      expect(threats.single.riskLevel, RiskLevel.high);
      expect(threats.single.radiusM, 5000);
      final distant = await service.loadMothThreats(
        currentUserId: 'farmer-a',
        anchors: [const LatLng(14, 121)],
      );
      expect(distant, isEmpty);
    },
  );
}
