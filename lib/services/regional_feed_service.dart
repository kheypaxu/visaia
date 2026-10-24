import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:visaia/utils/location_constants.dart';

class RegionalFeedException implements Exception {
  final String message;
  const RegionalFeedException(this.message);
  @override
  String toString() => message;
}

/// An explicitly validated public projection; never a raw Firestore document.
class RegionalFeedSnapshot {
  final DateTime generatedAt;
  final List<Map<String, dynamic>> assessment;
  final List<Map<String, dynamic>> threats;
  const RegionalFeedSnapshot({
    required this.generatedAt,
    required this.assessment,
    required this.threats,
  });

  factory RegionalFeedSnapshot.fromJson(Map<String, dynamic> json) {
    Never invalid() => throw const RegionalFeedException(
      'Regional information is unavailable. Please try again.',
    );
    Map<String, dynamic> object(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : invalid();
    int count(dynamic value) =>
        value is int && value >= 0 && value <= 1000000000000
        ? value
        : invalid();
    String barangay(dynamic value) =>
        value is String && LocationConstants.cabatuanBarangays.contains(value)
        ? value
        : invalid();
    if (json['schemaVersion'] != 1 ||
        json['municipality'] != LocationConstants.defaultMunicipality) {
      invalid();
    }
    final generated = DateTime.tryParse(json['generatedAt']?.toString() ?? '');
    if (generated == null ||
        json['assessment'] is! List ||
        json['threats'] is! List) {
      invalid();
    }
    const stages = ['egg', 'larva', 'pupa', 'moth'];
    const growth = [
      'Seedling',
      'Early Vegetative',
      'Late Vegetative',
      'Tasseling-Silking',
      'Grain Fill',
      'Maturity',
    ];
    final assessment = <Map<String, dynamic>>[];
    final stageSet = <String>{};
    for (final raw in json['assessment'] as List) {
      final item = object(raw);
      if (!stages.contains(item['stage']) ||
          !stageSet.add(item['stage'] as String) ||
          item['findings'] is! List) {
        invalid();
      }
      final findings = <Map<String, dynamic>>[];
      final barangays = <String>{};
      for (final rawFinding in item['findings'] as List) {
        final finding = object(rawFinding);
        final name = barangay(finding['barangay']);
        if (!barangays.add(name) || finding['growthStages'] is! List) invalid();
        final labels = finding['growthStages'] as List;
        if (labels.any((value) => !growth.contains(value))) invalid();
        findings.add({
          'barangay': name,
          'count': count(finding['count']),
          'growthStages': labels.cast<String>().toList(),
        });
      }
      final total = count(item['total']);
      if (findings.fold<int>(
            0,
            (sum, value) => sum + (value['count'] as int),
          ) !=
          total) {
        invalid();
      }
      assessment.add({
        'stage': item['stage'],
        'total': total,
        'findings': findings,
      });
    }
    final threats = <Map<String, dynamic>>[];
    final ids = <String>{};
    for (final raw in json['threats'] as List) {
      final item = object(raw);
      final id = item['id'];
      if (id is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
          !ids.add(id)) {
        invalid();
      }
      if (item['isClustered'] is! bool ||
          !['larva', 'moth'].contains(item['stage']) ||
          item['thresholdReached'] is! bool) {
        invalid();
      }
      final location = object(item['location']);
      final lat = location['lat'];
      final lng = location['lng'];
      if (lat is! num ||
          lng is! num ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat.abs() > 90 ||
          lng.abs() > 180 ||
          (lat == 0 && lng == 0)) {
        invalid();
      }
      final rawCounts = object(item['counts']);
      final counts = {
        for (final stage in stages) stage: count(rawCounts[stage]),
      };
      final damage = item['damagePercentage'];
      if (damage is! num || !damage.isFinite || damage < 0 || damage > 100) {
        invalid();
      }
      if (![
        null,
        'Very Low',
        'Low',
        'Moderate',
        'High',
        'Very High',
      ].contains(item['risk'])) {
        invalid();
      }
      final timestamp = item['timestamp'];
      if (timestamp != null &&
          (timestamp is! String || DateTime.tryParse(timestamp) == null)) {
        invalid();
      }
      threats.add({
        'id': id,
        'isClustered': item['isClustered'],
        'stage': item['stage'],
        'barangay': barangay(item['barangay']),
        'location': {'lat': lat.toDouble(), 'lng': lng.toDouble()},
        'counts': counts,
        'dap': count(item['dap']),
        'risk': item['risk'],
        'damagePercentage': damage.toDouble(),
        'thresholdReached': item['thresholdReached'],
        'timestamp': timestamp,
      });
    }
    if (assessment.length > 4 || threats.length > 400) invalid();
    return RegionalFeedSnapshot(
      generatedAt: generated,
      assessment: assessment,
      threats: threats,
    );
  }
}

class RegionalFeedClient {
  static final instance = RegionalFeedClient();
  final http.Client _http;
  final String? Function() _uid;
  final Future<String?> Function() _token;
  final DateTime Function() _now;
  final String baseUrl;
  final _cache = <String, ({DateTime expires, RegionalFeedSnapshot data})>{};
  final _inflight = <String, Future<RegionalFeedSnapshot>>{};
  RegionalFeedClient({
    http.Client? client,
    String? Function()? currentUid,
    Future<String?> Function()? token,
    DateTime Function()? now,
    this.baseUrl = const String.fromEnvironment(
      'PUSH_BACKEND_URL',
      defaultValue: 'https://visaia-web.vercel.app',
    ),
  }) : _http = client ?? http.Client(),
       _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _token =
           token ??
           (() async => FirebaseAuth.instance.currentUser?.getIdToken()),
       _now = now ?? DateTime.now;

  Future<RegionalFeedSnapshot> load({
    String municipality = LocationConstants.defaultMunicipality,
    String? expectedUserId,
  }) async {
    final uid = _uid();
    if (uid == null || (expectedUserId != null && uid != expectedUserId)) {
      throw const RegionalFeedException(
        'Sign in online to load regional information.',
      );
    }
    final key = '$uid:$municipality';
    final cached = _cache[key];
    if (cached != null && _now().isBefore(cached.expires)) return cached.data;
    final pending = _inflight[key];
    if (pending != null) return pending;
    final request = _fetch(uid, municipality);
    _inflight[key] = request;
    try {
      final data = await request;
      if (_uid() != uid) {
        throw const RegionalFeedException(
          'Account changed. Reload regional information.',
        );
      }
      final age = _now().difference(data.generatedAt).inSeconds;
      final remaining = (300 - age).clamp(0, 300);
      _cache[key] = (
        expires: _now().add(Duration(seconds: remaining)),
        data: data,
      );
      return data;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<RegionalFeedSnapshot> _fetch(String uid, String municipality) async {
    try {
      final token = await _token().timeout(const Duration(seconds: 10));
      if (token == null || _uid() != uid) {
        throw const RegionalFeedException(
          'Sign in online to load regional information.',
        );
      }
      final url = Uri.parse(
        '$baseUrl/api/mobile/regional-risk',
      ).replace(queryParameters: {'municipality': municipality});
      final response = await _http
          .get(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (_uid() != uid) {
        throw const RegionalFeedException(
          'Account changed. Reload regional information.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const RegionalFeedException(
          'Sign in with a verified account to load regional information.',
        );
      }
      if (response.statusCode != 200) {
        throw const RegionalFeedException(
          'Regional information is temporarily unavailable. Please try again later.',
        );
      }
      return RegionalFeedSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    } on RegionalFeedException {
      rethrow;
    } catch (_) {
      throw const RegionalFeedException(
        'Could not load regional information. Check your connection and try again.',
      );
    }
  }

  Stream<RegionalFeedSnapshot> watch({
    String municipality = LocationConstants.defaultMunicipality,
  }) => _RegionalFeedWatch(this, municipality).stream;
}

class _RegionalFeedWatch with WidgetsBindingObserver {
  final RegionalFeedClient client;
  final String municipality;
  late final StreamController<RegionalFeedSnapshot> _controller;
  Timer? _timer;
  bool _busy = false;
  bool _paused = false;
  String? _owner;
  _RegionalFeedWatch(this.client, this.municipality) {
    _controller = StreamController<RegionalFeedSnapshot>(
      onListen: () {
        _owner = client._uid();
        WidgetsBinding.instance.addObserver(this);
        unawaited(_refresh());
      },
      onPause: () {
        _paused = true;
        _timer?.cancel();
      },
      onResume: () {
        _paused = false;
        unawaited(_refresh());
      },
      onCancel: () {
        _timer?.cancel();
        WidgetsBinding.instance.removeObserver(this);
      },
    );
  }
  Stream<RegionalFeedSnapshot> get stream => _controller.stream;
  Future<void> _refresh() async {
    if (_busy ||
        _paused ||
        !_controller.hasListener ||
        client._uid() != _owner) {
      return;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    _busy = true;
    var nextRefreshSeconds = 300;
    try {
      final data = await client.load(
        municipality: municipality,
        expectedUserId: _owner,
      );
      nextRefreshSeconds =
          (300 - client._now().difference(data.generatedAt).inSeconds).clamp(
            30,
            300,
          );
      if (_controller.hasListener && client._uid() == _owner) {
        _controller.add(data);
      }
    } catch (error, stack) {
      if (_controller.hasListener) _controller.addError(error, stack);
    } finally {
      _busy = false;
      _timer?.cancel();
      if (_controller.hasListener && !_paused) {
        _timer = Timer(
          Duration(seconds: nextRefreshSeconds),
          () => unawaited(_refresh()),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    } else {
      _timer?.cancel();
    }
  }
}
