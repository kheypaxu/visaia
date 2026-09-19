import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

class MonitoringFirestoreService {
  final FirebaseFirestore _db;
  final String _userId;

  MonitoringFirestoreService({FirebaseFirestore? db, required String userId})
      : _db = db ?? FirebaseFirestore.instance,
        _userId = userId;

  Future<DocumentSnapshot<Map<String, dynamic>>> _getWithCacheFallback(
      DocumentReference<Map<String, dynamic>> ref) async {
    return ref.safeGet();
  }

  Future<Map<String, dynamic>?> getCycle(String cycleId) async {
    final doc = await _getWithCacheFallback(_db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(cycleId));
    return doc.exists ? doc.data() : null;
  }

  Future<Map<String, dynamic>?> getWeek(
      String cycleId, String weekId) async {
    final doc = await _getWithCacheFallback(_db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(cycleId)
        .collection('weeks')
        .doc(weekId));
    return doc.exists ? doc.data() : null;
  }

  Future<void> saveWeek(
      String cycleId, String weekId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(cycleId)
        .collection('weeks')
        .doc(weekId)
        .set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getDailyLog(
      String cycleId, String dayId) async {
    final doc = await _getWithCacheFallback(_db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(cycleId)
        .collection('dailyLogs')
        .doc(dayId));
    return doc.exists ? doc.data() : null;
  }

  Future<void> saveDailyLog(
      String cycleId, String dayId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(cycleId)
        .collection('dailyLogs')
        .doc(dayId)
        .set(data, SetOptions(merge: true));
  }
}