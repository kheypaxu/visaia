import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/services/connectivity_service.dart';

/// Provides resilient, offline-first get methods for Firestore DocumentReferences.
/// Prevents the UI from hanging when the device is offline or has poor network.
extension SafeFirestoreDocRefExt<T> on DocumentReference<T> {
  Future<DocumentSnapshot<T>> safeGet({
    Duration onlineTimeout = const Duration(milliseconds: 2500),
  }) async {
    final isOnline = ConnectivityService().isOnline;

    if (!isOnline) {
      return get(const GetOptions(source: Source.cache));
    }

    try {
      return await get().timeout(
        onlineTimeout,
        onTimeout: () => get(const GetOptions(source: Source.cache)),
      );
    } catch (_) {
      try {
        return await get(const GetOptions(source: Source.cache));
      } catch (e) {
        rethrow;
      }
    }
  }
}

/// Provides resilient, offline-first get methods for Firestore Queries.
/// Prevents the UI from hanging when the device is offline or has poor network.
extension SafeFirestoreQueryExt<T> on Query<T> {
  Future<QuerySnapshot<T>> safeGet({
    Duration onlineTimeout = const Duration(milliseconds: 2500),
  }) async {
    final isOnline = ConnectivityService().isOnline;

    if (!isOnline) {
      return get(const GetOptions(source: Source.cache));
    }

    try {
      return await get().timeout(
        onlineTimeout,
        onTimeout: () => get(const GetOptions(source: Source.cache)),
      );
    } catch (_) {
      try {
        return await get(const GetOptions(source: Source.cache));
      } catch (e) {
        rethrow;
      }
    }
  }
}
