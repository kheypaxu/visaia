import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visaia/services/api_service.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Represents a queued offline item waiting for network synchronization.
class QueuedOfflineItem {
  final String id;
  final String? docId;
  final String type; // 'pest_report', 'daily_log', etc.
  final String imagePath;
  final String userId;
  final String? farmerName;
  final String? farmId;
  final String? farmName;
  final String? fieldId;
  final String? fieldName;
  final String? cycleId;
  final double latitude;
  final double longitude;
  final String areaName;
  final int timestamp;
  String status; // 'pending', 'syncing', 'failed', 'synced'
  String? errorMessage;
  AnalysisResult? result;
  Map<String, dynamic>? submission;
  Map<String, dynamic>? assignment;
  Map<String, dynamic>? get lockedAssignment => assignment ?? submission;
  bool get isAssigned =>
      (lockedAssignment?['cycleId'] as String? ?? '').isNotEmpty;

  bool get isReady => result != null && status != 'submitted';
  bool get needsSync =>
      status != 'submitted' && (result == null || submission != null);
  String get statusLabel {
    switch (status) {
      case 'uploading':
        return 'Uploading photo';
      case 'analyzing':
        return 'Waiting for AI result';
      case 'ready':
        return isAssigned
            ? 'Cycle assigned - ready to save'
            : 'Ready to review';
      case 'submitting':
        return 'Saving report';
      case 'failed':
        return submission != null
            ? 'Report save needs retry'
            : 'Analysis needs retry';
      case 'submitted':
        return 'Report saved';
      default:
        return submission != null
            ? 'Report save waiting to sync'
            : 'Waiting to sync';
    }
  }

  QueuedOfflineItem({
    required this.id,
    this.docId,
    required this.type,
    required this.imagePath,
    required this.userId,
    this.farmerName,
    this.farmId,
    this.farmName,
    this.fieldId,
    this.fieldName,
    this.cycleId,
    required this.latitude,
    required this.longitude,
    required this.areaName,
    required this.timestamp,
    this.status = 'pending',
    this.errorMessage,
    this.result,
    this.submission,
    this.assignment,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'docId': docId,
    'type': type,
    'imagePath': imagePath,
    'userId': userId,
    'farmerName': farmerName,
    'farmId': farmId,
    'farmName': farmName,
    'fieldId': fieldId,
    'fieldName': fieldName,
    'cycleId': cycleId,
    'latitude': latitude,
    'longitude': longitude,
    'areaName': areaName,
    'timestamp': timestamp,
    'status': status,
    'errorMessage': errorMessage,
    'result': result?.toJson(),
    'submission': submission,
    'assignment': assignment,
  };

  factory QueuedOfflineItem.fromJson(Map<String, dynamic> json) =>
      QueuedOfflineItem(
        id: json['id'] as String,
        docId: json['docId'] as String?,
        type: json['type'] as String? ?? 'pest_report',
        imagePath: json['imagePath'] as String,
        userId: json['userId'] as String? ?? '',
        farmerName: json['farmerName'] as String?,
        farmId: json['farmId'] as String?,
        farmName: json['farmName'] as String?,
        fieldId: json['fieldId'] as String?,
        fieldName: json['fieldName'] as String?,
        cycleId: json['cycleId'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        areaName: json['areaName'] as String? ?? 'Unknown Area',
        timestamp:
            json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        status: json['status'] as String? ?? 'pending',
        errorMessage: json['errorMessage'] as String?,
        result: json['result'] is Map
            ? AnalysisResult.fromJson(
                Map<String, dynamic>.from(json['result'] as Map),
              )
            : null,
        assignment: json['assignment'] is Map
            ? Map<String, dynamic>.from(json['assignment'] as Map)
            : null,
        submission: json['submission'] is Map
            ? Map<String, dynamic>.from(json['submission'] as Map)
            : null,
      );
}

/// Central offline sync coordinator that persists offline actions, saves queued images,
/// and automatically processes and uploads items when online.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  @visibleForTesting
  OfflineSyncService.forTesting({
    required String? Function() currentOwner,
    required bool Function() online,
    required Future<AnalysisResult> Function(File, VoidCallback) analyze,
    required Future<void> Function(QueuedOfflineItem) commitReport,
    required Future<Directory> Function() documentsDirectory,
  }) : _currentOwnerOverride = currentOwner,
       _onlineOverride = online,
       _analyzeOverride = analyze,
       _commitOverride = commitReport,
       _documentsDirectoryOverride = documentsDirectory;

  final Map<String, Future<void>> _submissions = {};
  Future<void> Function(QueuedOfflineItem)? onAnalysisReady;
  String? Function()? _currentOwnerOverride;
  bool Function()? _onlineOverride;
  Future<AnalysisResult> Function(File, VoidCallback)? _analyzeOverride;
  Future<void> Function(QueuedOfflineItem)? _commitOverride;
  Future<Directory> Function()? _documentsDirectoryOverride;
  String? get _authenticatedOwner => _currentOwnerOverride != null
      ? _currentOwnerOverride!()
      : FirebaseAuth.instance.currentUser?.uid;
  bool get _online => _onlineOverride?.call() ?? ConnectivityService().isOnline;

  static const String _queuePrefsKey = 'visaia_offline_sync_queue_v1';

  final ValueNotifier<int> pendingSyncCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> syncStatusMessage = ValueNotifier<String?>(null);
  final ValueNotifier<int> queueRevision = ValueNotifier<int>(0);

  final List<QueuedOfflineItem> _queue = [];
  Future<void> _persistenceTail = Future<void>.value();

  String? _activeUserId;

  /// Returns the current active user ID from explicit context, Firebase Auth,
  /// or authenticated offline cache session.
  String? get currentUserId {
    if (_currentOwnerOverride != null) return _currentOwnerOverride!();
    if (_activeUserId != null && _activeUserId!.isNotEmpty) {
      return _activeUserId;
    }
    final fbUid = FirebaseAuth.instance.currentUser?.uid;
    if (fbUid != null && fbUid.isNotEmpty) {
      return fbUid;
    }
    try {
      final authCache = AuthCacheService();
      if ((authCache.isOfflineSessionActive || authCache.hasCachedSession) &&
          authCache.cachedUid != null &&
          authCache.cachedUid!.isNotEmpty) {
        return authCache.cachedUid;
      }
    } catch (_) {}
    return null;
  }

  /// Explicitly sets or updates the active user context (e.g. on login/logout or screen load).
  void updateCurrentUser(String? uid) {
    if (_activeUserId != uid) {
      _activeUserId = uid;
      _updatePendingCount();
    }
  }

  /// Recomputes pending count for the current user.
  void refresh() {
    _updatePendingCount();
  }

  /// Returns queued offline items belonging to the currently active user.
  List<QueuedOfflineItem> get queue {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return const [];
    return List.unmodifiable(_queue.where((i) => i.userId == uid));
  }

  /// Returns all queued offline items across all accounts (for internal device storage management).
  List<QueuedOfflineItem> get allQueueItems => List.unmodifiable(_queue);

  /// Returns the count of pending items for a specific user ID, or the current user if omitted.
  int getPendingCount([String? forUserId]) {
    final uid = forUserId ?? currentUserId;
    if (uid == null || uid.isEmpty) return 0;
    return _queue
        .where(
          (i) =>
              i.userId == uid &&
              i.status != 'synced' &&
              i.status != 'submitted',
        )
        .length;
  }

  void _updatePendingCount() {
    pendingSyncCount.value = getPendingCount();
    queueRevision.value++;
  }

  Future<void>? _initializing;
  Timer? _retryTimer;

  Future<void> init() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    await _loadQueue();
    if (_currentOwnerOverride != null) return;
    _retryTimer ??= Timer.periodic(const Duration(seconds: 45), (_) {
      if (ConnectivityService().isOnline && getPendingCount() > 0) {
        unawaited(syncAll());
      }
    });

    // Listen to Firebase Auth state changes so pending count stays scoped to the logged-in user
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _activeUserId = user?.uid;
      _updatePendingCount();

      // If user logs in while online and has pending items, attempt auto-sync for that user
      if (user != null &&
          ConnectivityService().isOnline &&
          getPendingCount(user.uid) > 0) {
        Future.delayed(
          const Duration(seconds: 2),
          () => syncAll(forUserId: user.uid),
        );
      }
    });

    // Listen to network reconnection events to trigger auto-sync for the current user only
    ConnectivityService().onConnectivityRestored.listen((isOnline) {
      final uid = currentUserId;
      if (isOnline &&
          uid != null &&
          uid.isNotEmpty &&
          getPendingCount(uid) > 0) {
        debugPrint(
          '🔄 Online restored: Auto-triggering offline sync queue for $uid (${getPendingCount(uid)} items)',
        );
        syncAll(forUserId: uid);
      }
    });

    // If already online on startup and current user has pending items, attempt sync
    final startupUid = currentUserId;
    if (ConnectivityService().isOnline &&
        startupUid != null &&
        getPendingCount(startupUid) > 0) {
      Future.delayed(
        const Duration(seconds: 2),
        () => syncAll(forUserId: startupUid),
      );
    }
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_queuePrefsKey) ?? [];
      _queue.clear();
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final item = QueuedOfflineItem.fromJson(decoded);
          if (item.status == 'synced' || item.status == 'submitted') continue;
          // In-flight network operations cannot survive process termination.
          // Completed inference and an attempted report save do survive.
          if ([
            'syncing',
            'uploading',
            'analyzing',
            'submitting',
          ].contains(item.status)) {
            item.status = item.result != null
                ? (item.submission != null ? 'failed' : 'ready')
                : 'pending';
          }
          _queue.add(item);
        } catch (e) {
          debugPrint('Error parsing queued item: $e');
        }
      }
      _updatePendingCount();
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
    }
  }

  Future<void> _saveQueue() {
    final operation = _persistenceTail.then((_) => _writeQueue());
    _persistenceTail = operation.catchError((Object error) {});
    return operation;
  }

  Future<void> _writeQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = _queue
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      if (!await prefs.setStringList(_queuePrefsKey, stringList)) {
        throw StateError('Could not save the offline queue on this device');
      }
      _updatePendingCount();
    } catch (e) {
      debugPrint('Error saving sync queue: $e');
      rethrow;
    }
  }

  /// Copies an image file into the app's persistent offline queue directory.
  Future<String> persistOfflineImage(File imageFile) async {
    final appDir =
        await (_documentsDirectoryOverride ??
            getApplicationDocumentsDirectory)();
    final queueDir = Directory('${appDir.path}/offline_queue');
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }

    final filename =
        'pest_${DateTime.now().microsecondsSinceEpoch}_${imageFile.uri.pathSegments.last}';
    final savedFile = await imageFile.copy('${queueDir.path}/$filename');
    return savedFile.path;
  }

  /// Stores a detection locally. A regular report is created only after review.
  Future<QueuedOfflineItem> enqueuePestReport({
    required File imageFile,
    required String userId,
    String? farmId,
    String? farmName,
    String? fieldId,
    String? fieldName,
    String? cycleId,
    required double latitude,
    required double longitude,
    required String areaName,
    String? farmerName,
  }) async {
    await init();
    if (userId.isEmpty) throw StateError('Sign in before saving a detection');
    final persistentPath = await persistOfflineImage(imageFile);
    final item = QueuedOfflineItem(
      id: 'offline_rep_${DateTime.now().microsecondsSinceEpoch}',
      type: 'pest_report',
      imagePath: persistentPath,
      userId: userId,
      farmerName: farmerName,
      farmId: farmId,
      farmName: farmName,
      fieldId: fieldId,
      fieldName: fieldName,
      cycleId: cycleId,
      latitude: latitude,
      longitude: longitude,
      areaName: areaName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _activeUserId = userId;
    _queue.add(item);
    try {
      await _saveQueue();
    } catch (_) {
      _queue.remove(item);
      rethrow;
    }
    if (_online) unawaited(syncAll(forUserId: userId));
    return item;
  }

  int get readyCount =>
      queue.where((i) => i.isReady && i.submission == null).length;
  bool get hasSyncWork => queue.any((i) => i.needsSync);

  QueuedOfflineItem? itemById(String id) {
    for (final item in queue) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _requireOwner(QueuedOfflineItem item) {
    if (_authenticatedOwner != item.userId || currentUserId != item.userId) {
      throw StateError('Sign in to the account that owns this detection');
    }
  }

  Future<void> syncAll({String? forUserId}) async {
    if (isSyncing.value || !_online) return;
    final uid = forUserId ?? currentUserId;
    if (uid == null || uid != _authenticatedOwner || uid != currentUserId) {
      return;
    }
    final items = _queue.where((i) => i.userId == uid && i.needsSync).toList();
    if (items.isEmpty) return;
    isSyncing.value = true;
    try {
      for (final item in items) {
        if (!_online || _authenticatedOwner != uid || currentUserId != uid) {
          break;
        }
        if (_submissions.containsKey(item.id)) continue;
        try {
          if (item.submission != null) {
            await _submitItem(item);
            continue;
          }
          if (item.type != 'pest_report') {
            throw StateError('Unsupported queued detection type: ${item.type}');
          }
          final image = File(item.imagePath);
          if (!await image.exists()) {
            throw StateError('Saved photo is missing on this device');
          }
          item.status = 'uploading';
          item.errorMessage = null;
          syncStatusMessage.value = 'Uploading photo';
          await _saveQueue();
          void imageSent() {
            item.status = 'analyzing';
            syncStatusMessage.value = 'Waiting for AI result';
            _updatePendingCount();
          }

          // Only persist "ready" after the complete result has been received.
          // Keep the photo; the user still needs to review and assign it.
          final result = await (_analyzeOverride != null
              ? _analyzeOverride!(image, imageSent)
              : ApiService.sendImage(image, onImageSent: imageSent));
          item.result = result;
          item.status = 'ready';
          item.errorMessage = null;
          await _saveQueue();
          // Notification failures must never turn a persisted result into a failure.
          try {
            await onAnalysisReady?.call(item);
          } catch (error) {
            debugPrint('AI result notification unavailable: $error');
          }
        } catch (error) {
          item.status = 'failed';
          item.errorMessage = error.toString();
          await _saveQueue();
        }
      }
      syncStatusMessage.value = readyCount > 0
          ? '$readyCount AI result(s) ready to review'
          : null;
    } catch (error) {
      syncStatusMessage.value =
          'Sync paused. Your detections remain on this device.';
      debugPrint('Could not persist detection progress: $error');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Persist the first successful cycle assignment independently of report save.
  /// Keep the in-memory lock even if persistence fails so retry cannot assign twice.
  Future<void> lockCycleAssignment(
    String id,
    Map<String, dynamic> assignment,
  ) async {
    final item = itemById(id);
    if (item == null || item.result == null) {
      throw StateError('This detection is no longer available');
    }
    _requireOwner(item);
    if ((assignment['cycleId'] as String? ?? '').isEmpty) {
      throw StateError('Select a cycle first');
    }
    final locked = item.lockedAssignment;
    if (locked != null) {
      for (final key in ['cycleId', 'weekNumber', 'station']) {
        if (locked[key] != assignment[key]) {
          throw StateError('This detection is already assigned to a cycle');
        }
      }
    }
    item.assignment ??= Map<String, dynamic>.from(assignment);
    _updatePendingCount();
    await _saveQueue();
  }

  /// Called only after explicit review, assignment and Save in AIResultScreen.
  /// Preserve assignment before networking so interrupted saves can retry safely.
  Future<String> submitReviewedReport(
    String id,
    Map<String, dynamic> data,
  ) async {
    final item = itemById(id);
    if (item == null || item.result == null) {
      throw StateError('This detection is no longer available');
    }
    _requireOwner(item);
    if (!_online) {
      throw StateError('Connect to the internet to save your report');
    }
    if ((data['cycleId'] as String? ?? '').isEmpty) {
      throw StateError(
        'Assign this detection to a farming cycle before saving',
      );
    }
    if (_submissions.containsKey(id)) {
      throw StateError('This report is already being saved');
    }
    final assignment = item.assignment;
    if (assignment != null) {
      for (final key in ['cycleId', 'weekNumber', 'station']) {
        if (assignment[key] != data[key]) {
          throw StateError(
            'This detection is already assigned to a different cycle, week or station',
          );
        }
      }
    }
    final submission = Map<String, dynamic>.from(data)
      ..remove('timestamp')
      ..remove('imageBase64');
    submission['farmerId'] = item.userId;
    submission['sourceQueueId'] = item.id;
    submission['submittedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    submission['observedAtMs'] = item.timestamp;
    // Freeze the payload on the first attempt. A late server ACK must not let a
    // retry create a second report or change a previously submitted assignment.
    item.submission ??= submission;
    await _saveQueue();
    await _submitItem(item);
    return item.id;
  }

  Future<void> _submitItem(QueuedOfflineItem item) {
    final ongoing = _submissions[item.id];
    if (ongoing != null) return ongoing;
    final operation = _performSubmit(item);
    _submissions[item.id] = operation;
    return operation;
  }

  Future<void> _performSubmit(QueuedOfflineItem item) async {
    try {
      _requireOwner(item);
      item.status = 'submitting';
      item.errorMessage = null;
      await _saveQueue();
      if (_commitOverride != null) {
        await _commitOverride!(item);
      } else {
        await _commitReport(item);
      }
      item.status = 'submitted';
      // If persistence fails, keep the image and stable identity for recovery.
      await _saveQueue();
      _queue.remove(item);
      _updatePendingCount();
      try {
        final image = File(item.imagePath);
        if (await image.exists()) await image.delete();
      } catch (error) {
        debugPrint('Could not remove submitted detection photo: $error');
      }
    } catch (error) {
      item.status = 'failed';
      item.errorMessage = error.toString();
      await _saveQueue();
      rethrow;
    } finally {
      _submissions.remove(item.id);
    }
  }

  Future<void> _commitReport(QueuedOfflineItem item) async {
    _requireOwner(item);
    final ref = FirebaseFirestore.instance.collection('reports').doc(item.id);
    // Confirm an earlier attempt before writing again, including late ACKs and
    // already validated reports. Legacy placeholders keep their identity and
    // are linked below; their rules forbid changing cycle ownership/assignment.
    try {
      final existing = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      final data = existing.data();
      if (data != null &&
          data['farmerId'] == item.userId &&
          data['sourceQueueId'] == item.id) {
        return;
      }
      if (data != null) {
        throw StateError(
          'An existing report needs review before it can be replaced',
        );
      }
    } on FirebaseException catch (error) {
      // Owner-read rules can reject reads of an as-yet nonexistent document.
      // Creation still goes through the existing ownership/security rules.
      if (error.code != 'permission-denied') rethrow;
    }
    final image = await encodeReportImage(File(item.imagePath));
    _requireOwner(item);
    final data = Map<String, dynamic>.from(item.submission!);
    final submittedAtMs = data.remove('submittedAtMs') as int;
    final observedAtMs = data.remove('observedAtMs') as int;
    await ref
        .set({
          ...data,
          'imageBase64': image,
          'farmerId': item.userId,
          'sourceQueueId': item.id,
          if (item.docId != null) 'legacyOfflineReportId': item.docId,
          'timestamp': Timestamp.fromMillisecondsSinceEpoch(submittedAtMs),
          'observedAt': Timestamp.fromMillisecondsSinceEpoch(observedAtMs),
          'status': 'pending',
          'isOfflineRecord': false,
        })
        .timeout(const Duration(seconds: 20));
  }

  /// One portable data-URL format for the online and reviewed-offline save paths.
  static Future<String> encodeReportImage(File image) async {
    Uint8List? bytes;
    for (final quality in [65, 45, 25]) {
      bytes = await FlutterImageCompress.compressWithFile(
        image.path,
        minWidth: 640,
        minHeight: 640,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (bytes != null && bytes.length < 500000) {
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    }
    throw StateError(
      'Could not prepare a small enough photo. Your detection is still saved.',
    );
  }

  /// Explicit removal is blocked while analysis or submission owns the item.
  Future<void> removeItem(String id) async {
    final item = itemById(id);
    if (item == null) return;
    if (isSyncing.value || _submissions.containsKey(id)) {
      throw StateError('Wait for the current sync to finish');
    }
    if (item.submission != null) {
      throw StateError(
        'An earlier report save is awaiting confirmation. Retry saving before removing this detection.',
      );
    }
    _queue.remove(item);
    try {
      await _saveQueue();
    } catch (_) {
      _queue.add(item);
      rethrow;
    }
    try {
      final image = File(item.imagePath);
      if (await image.exists()) await image.delete();
    } catch (error) {
      debugPrint('Could not remove discarded detection photo: $error');
    }
  }
}
