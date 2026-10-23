import 'package:visaia/services/local_write_ack.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Waits for the local Firestore snapshot, rather than requiring a network ACK.
/// Firestore's persistent mutation queue remains responsible for delivery.
class LocalWriteService {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final pendingCount = ValueNotifier<int>(0);
  static final Map<String, StreamSubscription<dynamic>> _watchers = {};
  static final Map<String, String?> _owners = {};
  static const _prefsKey = 'firestore_pending_paths_v1';
  static String? _userId;
  static String? get _effectiveUserId => _userId ??
      (AuthCacheService().isOfflineSessionActive
          ? AuthCacheService().cachedUid
          : null);
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    for (final entry in _prefs!.getStringList(_prefsKey) ?? <String>[]) {
      final separator = entry.indexOf('|');
      final path = separator < 0 ? entry : entry.substring(separator + 1);
      final owner = separator < 0 ? null : entry.substring(0, separator);
      _watch(FirebaseFirestore.instance.doc(path), ownerId: owner);
    }
  }

  static void setUser(String? userId) {
    _userId = userId;
    _refreshCount();
  }

  static void _refreshCount() {
    final userId = _effectiveUserId;
    pendingCount.value = _watchers.keys
        .where((path) => userId != null && _owners[path] == userId)
        .length;
  }

  static Future<void> _persist() async {
    _refreshCount();
    try {
      await _prefs?.setStringList(
        _prefsKey,
        _watchers.keys.map((path) => '${_owners[path] ?? ''}|$path').toList(),
      );
    } catch (error) {
      // These are display hints; Firestore itself persists the mutations.
      debugPrint('Could not persist pending-write indicators: $error');
    }
  }

  static void _watch(
    DocumentReference<Map<String, dynamic>> ref, {
    String? ownerId,
  }) {
    if (_watchers.containsKey(ref.path)) return;
    _owners[ref.path] =
        ownerId ??
        (ref.path.startsWith('users/') ? ref.path.split('/')[1] : _effectiveUserId);
    _watchers[ref.path] = ref.snapshots(includeMetadataChanges: true).listen((
      snapshot,
    ) {
      if (!snapshot.metadata.hasPendingWrites &&
          !snapshot.metadata.isFromCache) {
        _finish(ref.path);
      }
    }, onError: (Object error) => _finish(ref.path));
    _refreshCount();
  }

  static void _finish(String path) {
    _owners.remove(path);
    unawaited(_watchers.remove(path)?.cancel());
    unawaited(_persist());
  }

  static Future<void> run(
    DocumentReference<Map<String, dynamic>> ref,
    Future<void> Function() write,
  ) async {
    try {
      await waitForLocalWrite(
        pendingWrites: ref
            .snapshots(includeMetadataChanges: true)
            .map((snapshot) => snapshot.metadata.hasPendingWrites),
        write: () {
          final future = write();
          _watch(ref);
          unawaited(_persist());
          return future;
        },
        onAcknowledged: () => _finish(ref.path),
        onLateError: (error) {
          messengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('A saved change could not sync: $error')),
          );
        },
      );
    } catch (_) {
      _finish(ref.path);
      rethrow;
    }
  }
}

extension LocalDocumentWrites on DocumentReference<Map<String, dynamic>> {
  Future<void> setLocally(Map<String, dynamic> data, [SetOptions? options]) =>
      LocalWriteService.run(this, () => set(data, options));

  Future<void> updateLocally(Map<Object, Object?> data) =>
      LocalWriteService.run(this, () => update(data));

  Future<void> deleteLocally() => LocalWriteService.run(this, delete);
}

extension LocalCollectionWrites on CollectionReference<Map<String, dynamic>> {
  Future<DocumentReference<Map<String, dynamic>>> addLocally(
    Map<String, dynamic> data,
  ) async {
    final ref = doc();
    await ref.setLocally(data);
    return ref;
  }
}
