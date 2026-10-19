import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:visaia/utils/growth_stage.dart';
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

class _BarangayAccumulator {
  int count = 0;
  final Set<String> growthStages = <String>{};
}

// ======================= ACTIVITY FEED MODELS =======================

enum ActivityFeedKind {
  dailyLog,
  scouting,
  pestReport,
}

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

/// Watches every farmer inside a municipality and rolls up the FAW life
/// stages observed there.
///
/// Only reports that a DA-RCPC expert validated are part of the assessment:
///
///  * `clustered_reports` – official weekly scouting reports. The adjusted
///    station counters of the validated report hold the confirmed numbers.
///  * `reports` – pest detection reports, one observation per report.
///
/// Reports that are still pending, already resolved or rejected are left
/// out, so the assessment only shows confirmed FAW presence.
///
/// The result groups the observations by FAW life stage, then lists the
/// barangay where the stage was found together with the number found.
class MunicipalFawService {
  final FirebaseFirestore _db;
  final String municipality;

  /// Barangay of every farmer known through the `farmers` collection.
  final Map<String, String> _farmerBarangays = {};

  MunicipalFawService({
    FirebaseFirestore? db,
    this.municipality = LocationConstants.defaultMunicipality,
  }) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<FawLifeStageReport>> watchFawAssessment() {
    late final StreamController<List<FawLifeStageReport>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? municipalitySub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? barangaySub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? farmersSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? reportsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? clusteredSub;

    final Set<String> memberUids = <String>{};
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> userDocs =
        {};
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reportDocs = const [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clusteredDocs = const [];

    var recomputing = false;
    var recomputeQueued = false;
    Timer? debounce;

    Future<void> recompute() async {
      if (recomputing) {
        recomputeQueued = true;
        return;
      }
      recomputing = true;
      try {
        do {
          recomputeQueued = false;
          final reports = await _buildReports(
            memberUids,
            userDocs,
            reportDocs,
            clusteredDocs,
          );
          if (!controller.isClosed) controller.add(reports);
        } while (recomputeQueued);
      } catch (e) {
        debugPrint('FAW assessment error: $e');
        if (!controller.isClosed) controller.add(const []);
      } finally {
        recomputing = false;
      }
    }

    // Several collections fire at the same time, so the roll-up is debounced
    // to avoid rebuilding it once per snapshot.
    void scheduleRecompute() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 400), recompute);
    }

    controller = StreamController<List<FawLifeStageReport>>(
      onListen: () {
        // Farmers that explicitly set their municipality.
        municipalitySub = _db
            .collection('users')
            .where('municipality', isEqualTo: municipality)
            .snapshots()
            .listen(
          (snap) {
            for (final doc in snap.docs) {
              memberUids.add(doc.id);
              userDocs[doc.id] = doc;
            }
            scheduleRecompute();
          },
          onError: (e) {
            debugPrint('watchFawAssessment users error: $e');
          },
        );

        // Farmers registered before the municipality field existed are matched
        // by their barangay instead.
        barangaySub = _db.collection('users').snapshots().listen(
          (snap) {
            for (final doc in snap.docs) {
              final barangay = (doc.data()['barangay'] ?? '').toString();
              if (_municipalityBarangay(barangay) == null) continue;
              memberUids.add(doc.id);
              userDocs[doc.id] = doc;
            }
            scheduleRecompute();
          },
          onError: (e) {
            debugPrint('watchFawAssessment barangay fallback error: $e');
          },
        );

        // Barangay of every farmer, used to attribute reports to a barangay.
        farmersSub = _db.collection('farmers').snapshots().listen(
          (snap) {
            for (final doc in snap.docs) {
              final barangay = (doc.data()['barangay'] ?? '').toString();
              if (barangay.trim().isEmpty) continue;
              _farmerBarangays[doc.id] = _canonicalBarangay(barangay);
              if (_municipalityBarangay(barangay) != null) {
                memberUids.add(doc.id);
              }
            }
            scheduleRecompute();
          },
          onError: (e) {
            debugPrint('watchFawAssessment farmers error: $e');
          },
        );

        // Official pest detection reports.
        reportsSub = _db.collection('reports').snapshots().listen(
          (snap) {
            reportDocs = snap.docs;
            scheduleRecompute();
          },
          onError: (e) {
            debugPrint('watchFawAssessment reports error: $e');
          },
        );

        // Official weekly scouting reports.
        clusteredSub = _db.collection('clustered_reports').snapshots().listen(
          (snap) {
            clusteredDocs = snap.docs;
            scheduleRecompute();
          },
          onError: (e) {
            debugPrint('watchFawAssessment clustered reports error: $e');
          },
        );
      },
      onCancel: () {
        debounce?.cancel();
        municipalitySub?.cancel();
        barangaySub?.cancel();
        farmersSub?.cancel();
        reportsSub?.cancel();
        clusteredSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<List<FawLifeStageReport>> _buildReports(
    Set<String> memberUids,
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reportDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clusteredDocs,
  ) async {
    // uid -> barangay for every farmer inside the municipality.
    final Map<String, String> uidToBarangay = {};
    for (final uid in memberUids) {
      final userDoc = userDocs[uid];
      final barangay = userDoc != null
          ? await _resolveBarangay(uid, userDoc.data())
          : (_farmerBarangays[uid] ?? '');
      if (barangay.isEmpty) continue;
      uidToBarangay[uid] = barangay;
    }

    if (uidToBarangay.isEmpty) return const [];

    final accumulators = <FawLifeStage, Map<String, _BarangayAccumulator>>{
      for (final stage in FawLifeStage.values)
        stage: <String, _BarangayAccumulator>{},
    };

    void record(
      FawLifeStage stage,
      String barangay,
      int count,
      String? growthStage,
    ) {
      if (count <= 0) return;
      final entry = accumulators[stage]!.putIfAbsent(
        barangay,
        () => _BarangayAccumulator(),
      );
      entry.count += count;
      final label = growthStageDisplayName(growthStage ?? '');
      if (label.isNotEmpty) entry.growthStages.add(label);
    }

    // ─── Official weekly scouting reports ───────────────────────────────
    // Only validated reports count, and only the newest report of a cycle
    // week is kept so that a re-submitted report is not counted twice.
    final Map<String, _ClusteredReport> clusteredByWeek = {};
    for (final doc in clusteredDocs) {
      final data = doc.data();
      if (!_isValidated(data)) continue;

      final uid = _ownerUid(data, uidToBarangay);
      if (uid == null) continue;

      final cycleId = (data['cycleId'] ?? '').toString().trim();
      final weekNumber = _asInt(data['weekNumber']);
      if (cycleId.isEmpty || weekNumber == null) continue;

      final key = '$uid#$cycleId#$weekNumber';
      final existing = clusteredByWeek[key];
      if (existing == null ||
          _reportTime(data).isAfter(existing.timestamp)) {
        clusteredByWeek[key] = _ClusteredReport(
          uid: uid,
          cycleId: cycleId,
          weekNumber: weekNumber,
          data: data,
          timestamp: _reportTime(data),
        );
      }
    }

    for (final report in clusteredByWeek.values) {
      final barangay = uidToBarangay[report.uid];
      if (barangay == null) continue;
      final growthStage = (report.data['growthStage'] ?? '').toString();

      // The DA-RCPC expert can correct the station counters while
      // validating, so the adjusted stations are preferred over the totals
      // that were captured when the report was filed.
      final stationCounts = _sumStations(report.data['stationsData']);
      if (stationCounts != null) {
        for (final stage in FawLifeStage.values) {
          record(
            stage,
            barangay,
            stationCounts[stage] ?? 0,
            growthStage,
          );
        }
        continue;
      }

      final totals = report.data['totals'];
      if (totals is Map) {
        for (final stage in FawLifeStage.values) {
          record(
            stage,
            barangay,
            _asInt(totals[stage.totalsField]) ?? 0,
            growthStage,
          );
        }
      }
    }

    // ─── Validated pest detection reports (one observation per report) ──
    for (final doc in reportDocs) {
      final data = doc.data();
      if (!_isValidated(data)) continue;

      final uid = _ownerUid(data, uidToBarangay);
      if (uid == null) continue;

      final stage = _mapLifeStage(
        data['lifeStage'] ?? data['stage'] ?? data['originalLifeStage'],
      );
      if (stage == null) continue;

      record(
        stage,
        uidToBarangay[uid]!,
        1,
        (data['growthStage'] ?? '').toString(),
      );
    }

    final reports = <FawLifeStageReport>[];
    for (final stage in FawLifeStage.values) {
      final barangays = accumulators[stage]!;
      if (barangays.isEmpty) continue;

      final findings = barangays.entries
          .map((entry) => FawBarangayFinding(
                barangay: entry.key,
                count: entry.value.count,
                growthStages: entry.value.growthStages,
              ))
          .toList()
        ..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          if (byCount != 0) return byCount;
          return a.barangay.compareTo(b.barangay);
        });

      reports.add(FawLifeStageReport(
        stage: stage,
        total: findings.fold<int>(0, (total, finding) => total + finding.count),
        findings: findings,
      ));
    }

    // The life stage with the most findings comes first.
    reports.sort((a, b) => b.total.compareTo(a.total));

    return reports;
  }

  /// The uid of the farmer that owns a report, when that farmer belongs to
  /// the municipality.
  String? _ownerUid(Map<String, dynamic> data, Map<String, String> uidToBarangay) {
    for (final key in const ['userId', 'farmerId']) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty && uidToBarangay.containsKey(value)) {
        return value;
      }
    }
    return null;
  }

  Future<String> _resolveBarangay(
      String uid, Map<String, dynamic> userData) async {
    final fromUser = _canonicalBarangay((userData['barangay'] ?? '').toString());
    if (fromUser.isNotEmpty) return fromUser;

    final fromFarmer = _canonicalBarangay(_farmerBarangays[uid] ?? '');
    if (fromFarmer.isNotEmpty) return fromFarmer;

    try {
      final farmerDoc = await _db.collection('farmers').doc(uid).get();
      return _canonicalBarangay(
          (farmerDoc.data()?['barangay'] ?? '').toString());
    } catch (e) {
      debugPrint('FAW assessment: could not resolve barangay for $uid: $e');
      return '';
    }
  }

  /// The canonical name of a barangay inside the municipality, or null when
  /// the name does not belong to it.
  String? _municipalityBarangay(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    for (final barangay in LocationConstants.cabatuanBarangays) {
      if (barangay.toLowerCase() == value.toLowerCase()) return barangay;
    }
    return null;
  }

  /// The municipality spelling of a barangay name, so the same barangay is
  /// never split over several rows because of casing or stray whitespace.
  String _canonicalBarangay(String raw) {
    final value = raw.trim();
    return _municipalityBarangay(value) ?? value;
  }
}

/// A clustered scouting report of a single cycle week.
class _ClusteredReport {
  final String uid;
  final String cycleId;
  final int weekNumber;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const _ClusteredReport({
    required this.uid,
    required this.cycleId,
    required this.weekNumber,
    required this.data,
    required this.timestamp,
  });
}

/// Only reports that a DA-RCPC expert validated are part of the assessment.
/// Pending, resolved and rejected reports are left out.
bool _isValidated(Map<String, dynamic> data) {
  final status = (data['status'] ?? '').toString().trim().toLowerCase();
  return status == 'validated';
}

/// Sums the life stage counters of a list of station maps.
///
/// Returns null when the report has no station list at all, so the caller can
/// fall back to the totals that were captured when the report was filed.
Map<FawLifeStage, int>? _sumStations(dynamic stations) {
  if (stations is! List || stations.isEmpty) return null;

  final counts = <FawLifeStage, int>{};
  for (final rawStation in stations) {
    if (rawStation is! Map) continue;
    final station = Map<String, dynamic>.from(rawStation);
    for (final stage in FawLifeStage.values) {
      final count = _asInt(station[stage.stationField]) ?? 0;
      if (count <= 0) continue;
      counts[stage] = (counts[stage] ?? 0) + count;
    }
  }
  return counts;
}

int? _asInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime _reportTime(Map<String, dynamic> data) {
  for (final key in const [
    'reportDate',
    'timestamp',
    'submittedAt',
    'createdAt',
    'dateConducted',
  ]) {
    final parsed = _parseDateTime(data[key]);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

FawLifeStage? _mapLifeStage(dynamic raw) {
  final value = (raw ?? '').toString().trim().toLowerCase();
  if (value.isEmpty) return null;
  if (value.contains('egg')) return FawLifeStage.egg;
  if (value.contains('larva')) return FawLifeStage.larva;
  if (value.contains('pupa')) return FawLifeStage.pupa;
  if (value.contains('moth') || value.contains('adult')) {
    return FawLifeStage.moth;
  }
  return null;
}

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
  }) =>
      _buildFeed(limit: limit, cycleFilter: cycleId);

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
      for (final sub in cycleSubs.remove(cycleId) ?? const <StreamSubscription<dynamic>>[]) {
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

      final cycleRef =
          _db.collection('users').doc(_userId).collection('cycles').doc(cycleId);
      final weekSubs = <StreamSubscription<dynamic>>[];
      final dayMap = <String, StreamSubscription<dynamic>>{};
      cycleSubs[cycleId] = weekSubs;
      daySubs[cycleId] = dayMap;

      // ---- Weekly field scouting -------------------------------------
      weekSubs.add(cycleRef.collection('weeks').snapshots().listen(
        (snap) {
          for (final doc in snap.docs) {
            final item = _scoutingItem(doc, cycleId, cycleName);
            if (item != null) cycleItems[item.id] = item;
          }
          emit();
        },
        onError: (e) => debugPrint('weeks watch error: $e'),
      ));

      // ---- Daily logs -----------------------------------------------
      weekSubs.add(cycleRef.collection('dailyLogs').snapshots().listen(
        (snap) {
          final days = snap.docs.toList()
            ..sort((a, b) =>
                _dayNumber(b.id).compareTo(_dayNumber(a.id)));
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
                .listen(
              (activitiesSnap) {
                for (final doc in activitiesSnap.docs) {
                  final item =
                      _dailyLogItem(doc, cycleId, dayId, cycleName);
                  if (item != null) cycleItems[item.id] = item;
                }
                emit();
              },
              onError: (e) => debugPrint('activities watch error: $e'),
            );
          }
          emit();
        },
        onError: (e) => debugPrint('dailyLogs watch error: $e'),
      ));
    }

    controller = StreamController<List<ActivityFeedItem>>(
      onListen: () {
        // ---- Cycles -------------------------------------------------
        rootSubs.add(_db
            .collection('users')
            .doc(_userId)
            .collection('cycles')
            .snapshots()
            .listen(
          (snap) {
            final wanted = <String, String>{};
            final candidates = <String, Map<String, dynamic>>{};

            for (final doc in snap.docs) {
              if (cycleFilter != null && doc.id != cycleFilter) continue;
              candidates[doc.id] = doc.data();
            }

            if (cycleFilter == null && candidates.length > _watchedCycles) {
              final sorted = candidates.keys.toList()
                ..sort((a, b) {
                  final aCreated = _parseDateTime(candidates[a]?['createdAt']);
                  final bCreated = _parseDateTime(candidates[b]?['createdAt']);
                  if (aCreated == null && bCreated == null) return a.compareTo(b);
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
          },
          onError: (e) => debugPrint('cycles watch error: $e'),
        ));

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

        rootSubs.add(_db
            .collection('reports')
            .where('farmerId', isEqualTo: _userId)
            .snapshots()
            .listen(handleReports,
                onError: (e) => debugPrint('reports watch error: $e')));

        rootSubs.add(_db
            .collection('reports')
            .where('userId', isEqualTo: _userId)
            .snapshots()
            .listen(handleReports,
                onError: (e) => debugPrint('reports watch error: $e')));
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
        _parseDateTime(data['timestamp']) ?? _parseDateTime(data['lastUpdated']);
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

    final weekNumber =
        int.tryParse(doc.id.replaceAll(RegExp(r'[^0-9]'), ''));

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

    final timestamp = _parseDateTime(data['timestamp']) ??
        _parseDateTime(data['date']);
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

    final timestamp = _parseDateTime(data['timestamp']) ??
        _parseDateTime(data['createdAt']);
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
