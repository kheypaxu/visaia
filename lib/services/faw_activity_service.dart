import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:visaia/services/regional_feed_service.dart';
import 'package:visaia/utils/location_constants.dart';

// ======================= FAW LIFE STAGE MODELS =======================

/// The FAW life stages that are recorded during weekly field scouting.
/// The [stationField] is the key used inside a station map of a `weeks` doc,
/// the [totalsField] is the key used inside the `totals` map of a
/// `clustered_reports` doc.
enum FawLifeStage {
  egg('Egg Masses', 'eggMasses', 'eggs'),
  larva('Larvae', 'larvae', 'larvae'),
  pupa('Pupae', 'pupae', 'pupae'),
  moth('Adult Moths', 'moths', 'moths');

  const FawLifeStage(this.label, this.stationField, this.totalsField);

  final String label;
  final String stationField;
  final String totalsField;
}

/// A single barangay that reported a given FAW life stage.
class FawBarangayFinding {
  final String barangay;
  final int count;

  /// Crop growth stages (Seedling, Early Vegetative, ...) where the life
  /// stage was recorded.
  final Set<String> growthStages;

  const FawBarangayFinding({
    required this.barangay,
    required this.count,
    required this.growthStages,
  });
}

/// Municipal roll-up of one FAW life stage.
class FawLifeStageReport {
  final FawLifeStage stage;
  final int total;
  final List<FawBarangayFinding> findings;

  const FawLifeStageReport({
    required this.stage,
    required this.total,
    required this.findings,
  });

  /// Crop growth stages where this life stage was recorded.
  Set<String> get growthStages {
    final stages = <String>{};
    for (final finding in findings) {
      stages.addAll(finding.growthStages);
    }
    return stages;
  }
}

// ======================= ACTIVITY FEED MODELS =======================

enum ActivityFeedKind { dailyLog, scouting, pestReport }

/// A single entry of the "Recent Activity" feed.
class ActivityFeedItem {
  final String id;
  final ActivityFeedKind kind;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? cycleId;
  final String? cycleName;
  final String? fieldName;

  const ActivityFeedItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.cycleId,
    this.cycleName,
    this.fieldName,
  });
}

// ======================= MUNICIPAL FAW SERVICE =======================

/// Reads only the authenticated server's public regional projection.
/// Private farmer profiles and raw reports never enter this service.
class MunicipalFawService {
  final RegionalFeedClient _feed;
  final String municipality;
  MunicipalFawService({
    RegionalFeedClient? feedClient,
    this.municipality = LocationConstants.defaultMunicipality,
  }) : _feed = feedClient ?? RegionalFeedClient.instance;

  Stream<List<FawLifeStageReport>> watchFawAssessment() =>
      _feed.watch(municipality: municipality).map(assessmentFromSnapshot);
}

List<FawLifeStageReport> assessmentFromSnapshot(
  RegionalFeedSnapshot snapshot,
) => snapshot.assessment
    .map(
      (data) => FawLifeStageReport(
        stage: FawLifeStage.values.firstWhere(
          (stage) => stage.name == data['stage'],
        ),
        total: data['total'] as int,
        findings: (data['findings'] as List)
            .map(
              (finding) => FawBarangayFinding(
                barangay: finding['barangay'] as String,
                count: finding['count'] as int,
                growthStages: (finding['growthStages'] as List)
                    .cast<String>()
                    .toSet(),
              ),
            )
            .toList(),
      ),
    )
    .toList();

// ======================= ACTIVITY FEED SERVICE =======================

/// Builds a live "Recent Activity" feed out of three sources:
///  * daily log activities  (`cycles/{cycleId}/dailyLogs/day_NN/activities`)
///  * weekly field scouting (`cycles/{cycleId}/weeks/week_N`)
///  * pest uploads          (`reports`)
class ActivityFeedService {
  final FirebaseFirestore _db;
  final String _userId;

  /// How many day documents of a cycle are watched for daily log activities.
  static const int _watchedDaysPerCycle = 5;

  /// How many cycles are watched when the feed is not scoped to one cycle.
  static const int _watchedCycles = 5;

  ActivityFeedService({FirebaseFirestore? db, required String userId})
    : _db = db ?? FirebaseFirestore.instance,
      _userId = userId;

  /// Recent activity across every cycle of the user.
  Stream<List<ActivityFeedItem>> watchUserActivity({int limit = 8}) =>
      _buildFeed(limit: limit);

  /// Recent activity restricted to a single cycle.
  Stream<List<ActivityFeedItem>> watchCycleActivity({
    required String cycleId,
    int limit = 8,
  }) => _buildFeed(limit: limit, cycleFilter: cycleId);

  Stream<List<ActivityFeedItem>> _buildFeed({
    required int limit,
    String? cycleFilter,
  }) {
    late final StreamController<List<ActivityFeedItem>> controller;

    final cycleItems = <String, ActivityFeedItem>{};
    final pestItems = <String, ActivityFeedItem>{};
    final cycleNames = <String, String>{};
    final cycleSubs = <String, List<StreamSubscription<dynamic>>>{};
    final daySubs = <String, Map<String, StreamSubscription<dynamic>>>{};
    final rootSubs = <StreamSubscription<dynamic>>[];

    void emit() {
      if (controller.isClosed) return;
      final all = <ActivityFeedItem>[...cycleItems.values, ...pestItems.values]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(all.take(limit).toList());
    }

    void clearCycle(String cycleId) {
      for (final sub
          in cycleSubs.remove(cycleId) ??
              const <StreamSubscription<dynamic>>[]) {
        sub.cancel();
      }
      final days = daySubs.remove(cycleId);
      if (days != null) {
        for (final sub in days.values) {
          sub.cancel();
        }
      }
      cycleItems.removeWhere((key, value) => value.cycleId == cycleId);
    }

    void subscribeCycle(String cycleId, String cycleName) {
      clearCycle(cycleId);

      final cycleRef = _db
          .collection('users')
          .doc(_userId)
          .collection('cycles')
          .doc(cycleId);
      final weekSubs = <StreamSubscription<dynamic>>[];
      final dayMap = <String, StreamSubscription<dynamic>>{};
      cycleSubs[cycleId] = weekSubs;
      daySubs[cycleId] = dayMap;

      // ---- Weekly field scouting -------------------------------------
      weekSubs.add(
        cycleRef.collection('weeks').snapshots().listen((snap) {
          for (final doc in snap.docs) {
            final item = _scoutingItem(doc, cycleId, cycleName);
            if (item != null) cycleItems[item.id] = item;
          }
          emit();
        }, onError: (e) => debugPrint('weeks watch error: $e')),
      );

      // ---- Daily logs -----------------------------------------------
      weekSubs.add(
        cycleRef.collection('dailyLogs').snapshots().listen((snap) {
          final days = snap.docs.toList()
            ..sort((a, b) => _dayNumber(b.id).compareTo(_dayNumber(a.id)));
          final keep = days.take(_watchedDaysPerCycle).map((d) => d.id).toSet();

          for (final key in dayMap.keys.toList()) {
            if (keep.contains(key)) continue;
            dayMap.remove(key)?.cancel();
          }

          for (final dayId in keep) {
            if (dayMap.containsKey(dayId)) continue;
            dayMap[dayId] = cycleRef
                .collection('dailyLogs')
                .doc(dayId)
                .collection('activities')
                .snapshots()
                .listen((activitiesSnap) {
                  for (final doc in activitiesSnap.docs) {
                    final item = _dailyLogItem(doc, cycleId, dayId, cycleName);
                    if (item != null) cycleItems[item.id] = item;
                  }
                  emit();
                }, onError: (e) => debugPrint('activities watch error: $e'));
          }
          emit();
        }, onError: (e) => debugPrint('dailyLogs watch error: $e')),
      );
    }

    controller = StreamController<List<ActivityFeedItem>>(
      onListen: () {
        // ---- Cycles -------------------------------------------------
        rootSubs.add(
          _db
              .collection('users')
              .doc(_userId)
              .collection('cycles')
              .snapshots()
              .listen((snap) {
                final wanted = <String, String>{};
                final candidates = <String, Map<String, dynamic>>{};

                for (final doc in snap.docs) {
                  if (cycleFilter != null && doc.id != cycleFilter) continue;
                  candidates[doc.id] = doc.data();
                }

                if (cycleFilter == null && candidates.length > _watchedCycles) {
                  final sorted = candidates.keys.toList()
                    ..sort((a, b) {
                      final aCreated = _parseDateTime(
                        candidates[a]?['createdAt'],
                      );
                      final bCreated = _parseDateTime(
                        candidates[b]?['createdAt'],
                      );
                      if (aCreated == null && bCreated == null) {
                        return a.compareTo(b);
                      }
                      if (aCreated == null) return 1;
                      if (bCreated == null) return -1;
                      return bCreated.compareTo(aCreated);
                    });
                  for (final id in sorted.skip(_watchedCycles)) {
                    candidates.remove(id);
                  }
                }

                for (final entry in candidates.entries) {
                  wanted[entry.key] =
                      (entry.value['cycleName'] ?? 'Cropping Cycle').toString();
                }

                for (final existing in cycleSubs.keys.toList()) {
                  if (!wanted.containsKey(existing)) clearCycle(existing);
                }

                for (final entry in wanted.entries) {
                  if (cycleNames[entry.key] == entry.value &&
                      cycleSubs.containsKey(entry.key)) {
                    continue;
                  }
                  cycleNames[entry.key] = entry.value;
                  subscribeCycle(entry.key, entry.value);
                }
                emit();
              }, onError: (e) => debugPrint('cycles watch error: $e')),
        );

        // ---- Pest uploads -------------------------------------------
        void handleReports(QuerySnapshot<Map<String, dynamic>> snap) {
          for (final doc in snap.docs) {
            final item = _pestItem(doc, (cycleId) => cycleNames[cycleId]);
            if (item == null) continue;
            if (cycleFilter != null && item.cycleId != cycleFilter) continue;
            pestItems[item.id] = item;
          }
          emit();
        }

        rootSubs.add(
          _db
              .collection('reports')
              .where('farmerId', isEqualTo: _userId)
              .snapshots()
              .listen(
                handleReports,
                onError: (e) => debugPrint('reports watch error: $e'),
              ),
        );

        rootSubs.add(
          _db
              .collection('reports')
              .where('userId', isEqualTo: _userId)
              .snapshots()
              .listen(
                handleReports,
                onError: (e) => debugPrint('reports watch error: $e'),
              ),
        );
      },
      onCancel: () {
        for (final sub in rootSubs) {
          sub.cancel();
        }
        for (final subs in cycleSubs.values) {
          for (final sub in subs) {
            sub.cancel();
          }
        }
        for (final days in daySubs.values) {
          for (final sub in days.values) {
            sub.cancel();
          }
        }
      },
    );

    return controller.stream;
  }

  ActivityFeedItem? _scoutingItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String cycleId,
    String cycleName,
  ) {
    final data = doc.data();

    final timestamp =
        _parseDateTime(data['timestamp']) ??
        _parseDateTime(data['lastUpdated']);
    if (timestamp == null) return null;

    var eggs = 0;
    var larvae = 0;
    var pupae = 0;
    var moths = 0;
    var completed = 0;
    var stationCount = 0;

    final stations = data['stations'];
    if (stations is List) {
      stationCount = stations.length;
      for (final rawStation in stations) {
        if (rawStation is! Map) continue;
        final station = Map<String, dynamic>.from(rawStation);
        eggs += (station['eggMasses'] as num?)?.toInt() ?? 0;
        larvae += (station['larvae'] as num?)?.toInt() ?? 0;
        pupae += (station['pupae'] as num?)?.toInt() ?? 0;
        moths += (station['moths'] as num?)?.toInt() ?? 0;
        if (station['completed'] == true) completed++;
      }
    } else {
      final totals = data['totals'];
      if (totals is Map) {
        eggs = (totals['eggs'] as num?)?.toInt() ?? 0;
        larvae = (totals['larvae'] as num?)?.toInt() ?? 0;
        pupae = (totals['pupae'] as num?)?.toInt() ?? 0;
        moths = (totals['moths'] as num?)?.toInt() ?? 0;
      }
    }

    final parts = <String>[];
    if (completed > 0 && stationCount > 0) {
      parts.add('$completed of $stationCount stations');
    }
    if (larvae > 0) parts.add('$larvae larvae');
    if (eggs > 0) parts.add('$eggs egg masses');
    if (pupae > 0) parts.add('$pupae pupae');
    if (moths > 0) parts.add('$moths moths');

    final weekNumber = int.tryParse(doc.id.replaceAll(RegExp(r'[^0-9]'), ''));

    return ActivityFeedItem(
      id: 'scouting:$cycleId:${doc.id}',
      kind: ActivityFeedKind.scouting,
      title: weekNumber != null
          ? 'Field Scouting · Week $weekNumber'
          : 'Field Scouting',
      subtitle: parts.isEmpty ? 'Scouting recorded' : parts.join(' • '),
      timestamp: timestamp,
      cycleId: cycleId,
      cycleName: cycleName,
    );
  }

  ActivityFeedItem? _dailyLogItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String cycleId,
    String dayId,
    String cycleName,
  ) {
    final data = doc.data();

    final timestamp =
        _parseDateTime(data['timestamp']) ?? _parseDateTime(data['date']);
    if (timestamp == null) return null;

    final type = (data['type'] ?? '').toString().trim();
    final notes = (data['notes'] ?? '').toString().trim();
    final status = (data['status'] ?? '').toString().trim();

    var subtitle = notes;
    if (status == 'scheduled') {
      subtitle = subtitle.isEmpty ? 'Scheduled' : 'Scheduled · $subtitle';
    } else if (status == 'in_progress') {
      subtitle = subtitle.isEmpty ? 'In progress' : 'In progress · $subtitle';
    }

    return ActivityFeedItem(
      id: 'daily:$cycleId:$dayId:${doc.id}',
      kind: ActivityFeedKind.dailyLog,
      title: type.isEmpty ? 'Daily Log' : type,
      subtitle: subtitle,
      timestamp: timestamp,
      cycleId: cycleId,
      cycleName: cycleName,
    );
  }

  ActivityFeedItem? _pestItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String? Function(String cycleId) cycleNameResolver,
  ) {
    final data = doc.data();

    final timestamp =
        _parseDateTime(data['timestamp']) ?? _parseDateTime(data['createdAt']);
    if (timestamp == null) return null;

    final pestName = (data['detection'] ?? data['pestName'] ?? 'Fall Army Worm')
        .toString()
        .trim();
    final stage = (data['lifeStage'] ?? data['stage'] ?? '').toString().trim();
    final risk = (data['risk'] ?? data['riskLevel'] ?? '').toString().trim();
    final fieldName = (data['fieldName'] ?? '').toString().trim();
    final cycleId = (data['cycleId'] ?? '').toString().trim();

    final parts = <String>[];
    if (stage.isNotEmpty) parts.add(_titleCase(stage));
    if (risk.isNotEmpty) parts.add('$risk risk');
    if (fieldName.isNotEmpty) parts.add(fieldName);

    return ActivityFeedItem(
      id: 'pest:${doc.id}',
      kind: ActivityFeedKind.pestReport,
      title: 'Pest Detected: $pestName',
      subtitle: parts.join(' • '),
      timestamp: timestamp,
      cycleId: cycleId.isEmpty ? null : cycleId,
      cycleName: cycleId.isEmpty ? null : cycleNameResolver(cycleId),
      fieldName: fieldName.isEmpty ? null : fieldName,
    );
  }

  int _dayNumber(String dayId) {
    final match = RegExp(r'(\d+)').firstMatch(dayId);
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}
