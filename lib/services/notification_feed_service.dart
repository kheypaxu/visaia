import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InboxNotification {
  final String id, title, message, reportId, reportType, status;
  final DateTime? createdAt;
  final bool unread;
  final String? alertId;
  final Map<String, dynamic> data;
  const InboxNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.reportId,
    required this.reportType,
    required this.status,
    required this.createdAt,
    required this.unread,
    required this.data,
    this.alertId,
  });
  bool get isReport => reportId.isNotEmpty && status.isNotEmpty;

  static DateTime? date(dynamic value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : value is String
      ? DateTime.tryParse(value)
      : null;

  static String reportStatus(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase();
    if (type.contains('reject')) return 'rejected';
    if (type.contains('validation_confirmed') || type.contains('validated')) {
      return 'validated';
    }
    if (type.contains('resolved')) return 'resolved';
    return '';
  }

  static List<InboxNotification> merge(List<InboxNotification> items) {
    // An explicit alert supersedes the report-derived entry for the same outcome.
    final explicit = items
        .where((n) => n.alertId != null && n.isReport)
        .toList();
    final unique = {for (final item in items) item.id: item};
    final result = unique.values
        .where(
          (n) =>
              n.alertId != null ||
              !explicit.any(
                (a) =>
                    a.reportId == n.reportId &&
                    a.status == n.status &&
                    (a.reportType.isEmpty || a.reportType == n.reportType),
              ),
        )
        .toList();
    result.sort(
      (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      ),
    );
    return result;
  }
}

/// Report entries reflect the latest saved status, not a fabricated event history.
/// Their read receipts are device-local until a server notification producer exists.
class NotificationFeedService {
  static final _changes = StreamController<String>.broadcast();
  static final _streams = <String, Stream<List<InboxNotification>>>{};
  static String _key(String uid) => 'notification_reads_v1_$uid';

  static Stream<List<InboxNotification>> watch(
    String uid,
  ) => _streams.putIfAbsent(
    uid,
    () => Stream<List<InboxNotification>>.multi((controller) {
      if (uid.isEmpty) {
        controller.add([]);
        controller.close();
        return;
      }
      final subscriptions = <StreamSubscription>[];
      final sources = <String, List<InboxNotification>>{};
      Set<String> read = {};
      bool closed = false;
      void emit() {
        if (!closed && sources.length == 4) {
          controller.add(
            InboxNotification.merge(sources.values.expand((v) => v).toList()),
          );
        }
      }

      final snapshots = <String, QuerySnapshot<Map<String, dynamic>>>{};
      void rebuild(String source) {
        final snapshot = snapshots[source];
        if (snapshot == null) return;
        sources[source] = snapshot.docs
            .where((doc) => doc.data()['status'] != 'deleted')
            .map((doc) {
              final d = doc.data();
              final alert = source == 'alerts';
              final status = alert
                  ? InboxNotification.reportStatus(d)
                  : (d['status'] ?? 'pending').toString().toLowerCase();
              final reportType = alert
                  ? (d['reportType'] ?? '').toString()
                  : source == 'regular'
                  ? 'regular'
                  : 'clustered';
              final reportId = alert
                  ? (d['reportId'] ?? '').toString()
                  : doc.id;
              final time = InboxNotification.date(
                alert
                    ? d['createdAt']
                    : d['${status}At'] ??
                          (status == 'validated' ? d['validatedAt'] : null) ??
                          d['statusUpdatedAt'] ??
                          d['updatedAt'] ??
                          d['submittedAt'] ??
                          d['createdAt'] ??
                          d['timestamp'],
              );
              final id = alert
                  ? 'alert:${doc.id}'
                  : 'report:$reportType:$reportId:$status:${InboxNotification.date(d['${status}At'] ?? d['statusUpdatedAt'])?.millisecondsSinceEpoch ?? 0}';
              final location = [
                d['farmName'],
                d['fieldName'] ?? d['areaName'],
              ].where((v) => v != null && v.toString().isNotEmpty).join(' / ');
              return InboxNotification(
                id: id,
                title: alert
                    ? (d['title'] ?? 'Farm alert').toString()
                    : '${reportType == 'clustered' ? 'Clustered' : 'Regular'} report ${status.replaceAll('_', ' ')}',
                message: alert
                    ? (d['message'] ?? d['detection'] ?? '').toString()
                    : [
                            location,
                            d['rejectionReason'] ??
                                d['validationNotes'] ??
                                d['resolutionExplanation'],
                          ]
                          .where((v) => v != null && v.toString().isNotEmpty)
                          .join(' / '),
                reportId: reportId,
                reportType: reportType,
                status: status,
                createdAt: time,
                unread: alert ? d['status'] == 'unread' : !read.contains(id),
                data: d,
                alertId: alert ? doc.id : null,
              );
            })
            .toList();
        emit();
      }

      Future<void> start() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          if (closed) return;
          read = (prefs.getStringList(_key(uid)) ?? []).toSet();
          subscriptions.add(
            _changes.stream.where((user) => user == uid).listen((_) {
              read = (prefs.getStringList(_key(uid)) ?? []).toSet();
              for (final source in snapshots.keys) {
                rebuild(source);
              }
            }),
          );
          final db = FirebaseFirestore.instance;
          final queries = {
            'alerts': db.collection('alerts').where('farmerId', isEqualTo: uid),
            'regular': db
                .collection('reports')
                .where('farmerId', isEqualTo: uid),
            'clustered': db
                .collection('clustered_reports')
                .where('farmerId', isEqualTo: uid),
            'clusteredUser': db
                .collection('clustered_reports')
                .where('userId', isEqualTo: uid),
          };
          for (final entry in queries.entries) {
            subscriptions.add(
              entry.value.snapshots().listen(
                (snapshot) {
                  snapshots[entry.key] = snapshot;
                  rebuild(entry.key);
                },
                onError: (Object error, StackTrace stack) {
                  if (!closed) controller.addError(error, stack);
                },
              ),
            );
          }
        } catch (error, stack) {
          if (!closed) controller.addError(error, stack);
        }
      }

      controller.onCancel = () {
        closed = true;
        for (final subscription in subscriptions) {
          subscription.cancel();
        }
      };
      start();
    }, isBroadcast: true),
  );

  static Future<void> markRead(
    String uid,
    Iterable<InboxNotification> items,
  ) async {
    final unread = items.where((n) => n.unread).toList();
    final alerts = unread.where((n) => n.alertId != null).toList();
    for (var i = 0; i < alerts.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final n in alerts.skip(i).take(400)) {
        batch.update(
          FirebaseFirestore.instance.collection('alerts').doc(n.alertId),
          {'status': 'read'},
        );
      }
      await batch.commit();
    }
    final prefs = await SharedPreferences.getInstance();
    final read = (prefs.getStringList(_key(uid)) ?? []).toSet()
      ..addAll(unread.where((n) => n.alertId == null).map((n) => n.id));
    if (!await prefs.setStringList(_key(uid), read.toList())) {
      throw StateError('Could not save notification read state');
    }
    _changes.add(uid);
  }
}
