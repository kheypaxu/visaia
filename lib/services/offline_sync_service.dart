import 'dart:async';
import 'package:visaia/services/local_write_service.dart';
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
      );
}

/// Central offline sync coordinator that persists offline actions, saves queued images,
/// and automatically processes and uploads items when online.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queuePrefsKey = 'visaia_offline_sync_queue_v1';

  final ValueNotifier<int> pendingSyncCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> syncStatusMessage = ValueNotifier<String?>(null);

  final List<QueuedOfflineItem> _queue = [];

  String? _activeUserId;

  /// Returns the current active user ID from explicit context, Firebase Auth,
  /// or authenticated offline cache session.
  String? get currentUserId {
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
    return _queue.where((i) => i.userId == uid && i.status != 'synced').length;
  }

  void _updatePendingCount() {
    pendingSyncCount.value = getPendingCount();
  }

  bool _isInitialized = false;
  Timer? _retryTimer;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadQueue();
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
          if (item.status != 'synced') _queue.add(item);
        } catch (e) {
          debugPrint('Error parsing queued item: $e');
        }
      }
      _updatePendingCount();
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
    }
  }

  Future<void> _saveQueue() async {
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
    final appDir = await getApplicationDocumentsDirectory();
    final queueDir = Directory('${appDir.path}/offline_queue');
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }

    final filename =
        'pest_${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split(Platform.pathSeparator).last}';
    final savedFile = await imageFile.copy('${queueDir.path}/$filename');
    return savedFile.path;
  }

  /// Enqueues a pest report recorded offline.
  /// Also creates a document in Firestore (which Firestore persists in its offline cache).
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

    if (userId.isEmpty) throw StateError('Sign in before saving a report');
    final persistentPath = await persistOfflineImage(imageFile);
    final itemId = 'offline_rep_${DateTime.now().millisecondsSinceEpoch}';

    final docRef = FirebaseFirestore.instance.collection('reports').doc();

    final item = QueuedOfflineItem(
      id: itemId,
      docId: docRef.id,
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

    // Create a local Firestore report record (Firestore queues this write offline)
    try {
      await docRef.setLocally({
        'farmerId': userId,
        'farmerName': farmerName ?? 'Farmer',
        'farmId': farmId,
        'farmName': farmName,
        'fieldId': fieldId,
        'fieldName': fieldName,
        'cycleId': cycleId,
        'pestName': 'Queued for AI Analysis',
        'scientificName': 'Pending online sync',
        'severity': 'Moderate',
        'riskLevel': 'Medium',
        'confidence': 0,
        'stage': 'Pending',
        'crop': 'Maize',
        'analysis':
            'Recorded offline. Detailed AI analysis and treatment plan will be generated once connected to internet.',
        'treatment': 'Synchronizing with AI server when online...',
        'status': 'pending_offline_sync',
        'timestamp': FieldValue.serverTimestamp(),
        'isOfflineRecord': true,
        'location': {'lat': latitude, 'lng': longitude, 'areaName': areaName},
        'lat': latitude,
        'lng': longitude,
      });
    } catch (e) {
      debugPrint('Note: Firestore doc write queued offline: $e');
    }

    // A backend failure while Wi-Fi remains connected also needs a retry.
    if (ConnectivityService().isOnline) {
      unawaited(syncAll(forUserId: userId));
    }

    debugPrint(
      '📦 Pest report queued for offline sync (ID: $itemId, User: $userId)',
    );
    return item;
  }

  /// Synchronizes queued offline items belonging to the active user (or specified user) with the AI backend and Firestore.
  Future<void> syncAll({String? forUserId}) async {
    if (isSyncing.value) return;
    if (!ConnectivityService().isOnline) {
      debugPrint('Cannot sync: Device is currently offline.');
      return;
    }

    final targetUserId = forUserId ?? currentUserId;
    if (targetUserId == null || targetUserId.isEmpty) {
      debugPrint('Cannot sync: No authenticated user session active.');
      return;
    }

    // Only process items that belong to the active user
    final pendingItems = _queue
        .where((i) => i.userId == targetUserId && i.status != 'synced')
        .toList();
    if (pendingItems.isEmpty) return;

    isSyncing.value = true;
    syncStatusMessage.value =
        'Syncing ${pendingItems.length} offline item(s)...';

    int successCount = 0;
    try {
      for (final item in pendingItems) {
        item.status = 'syncing';
        await _saveQueue();

        try {
          if (item.type == 'pest_report') {
            await _processPestReportItem(item);
            item.status = 'synced';
            item.errorMessage = null;
            successCount++;
          }
        } catch (e) {
          debugPrint('Failed to sync item ${item.id}: $e');
          item.status = 'failed';
          item.errorMessage = e.toString();
        }
        await _saveQueue();
        // Persist the synced state before removing the only local photo.
        if (item.status == 'synced') {
          try {
            final image = File(item.imagePath);
            if (await image.exists()) await image.delete();
          } catch (_) {}
        }
      }

      // Clean up successfully synced items from queue
      _queue.removeWhere((item) => item.status == 'synced');
      await _saveQueue();

      syncStatusMessage.value = successCount > 0
          ? 'Successfully synced $successCount offline report(s)!'
          : null;

      debugPrint(
        '✅ Sync finished for user $targetUserId: $successCount synced successfully.',
      );
    } catch (error) {
      syncStatusMessage.value =
          'Sync paused. Your reports remain on this device.';
      debugPrint('Could not persist sync progress: $error');
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _processPestReportItem(QueuedOfflineItem item) async {
    if (FirebaseAuth.instance.currentUser?.uid != item.userId) {
      throw StateError('Sign in to the account that owns this queued report');
    }
    final imageFile = File(item.imagePath);
    if (!await imageFile.exists()) {
      throw Exception('Queued image file not found on device');
    }

    // 1. Send image to AI backend
    final result = await ApiService.sendImage(imageFile);

    // 2. Compress image for Firestore document storage if cycle is present
    String? firestoreImageRef;
    String? imageBase64;
    try {
      Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 640,
        minHeight: 640,
        quality: 45,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes != null) {
        imageBase64 = base64Encode(compressedBytes);
        if (imageBase64.length > 850000) {
          throw StateError(
            'Pest image is too large; please choose a smaller image',
          );
        }
      }
      if (compressedBytes != null &&
          item.cycleId != null &&
          item.cycleId!.isNotEmpty) {
        final encoded = base64Encode(compressedBytes);
        final imgRef = FirebaseFirestore.instance
            .collection('users')
            .doc(item.userId)
            .collection('cycles')
            .doc(item.cycleId)
            .collection('images')
            .doc(item.id);

        await imgRef
            .set({
              'data': encoded,
              'contentType': 'image/jpeg',
              'category': 'pest_report',
              'createdAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 20));
        firestoreImageRef = 'firestore-image://${imgRef.path}';
      }
    } catch (e) {
      debugPrint('Warning: Could not compress/store Firestore image ref: $e');
      if ((imageBase64?.length ?? 0) > 850000) rethrow;
    }

    if (imageBase64 == null) {
      throw StateError('Could not preserve the pest image; it remains queued');
    }

    // 3. Map severity
    final risk = result.riskLevel.toLowerCase();
    final severity = (risk == 'high' || risk == 'critical' || risk == 'severe')
        ? 'High'
        : (risk == 'medium' || risk == 'moderate')
        ? 'Medium'
        : 'Low';

    if (FirebaseAuth.instance.currentUser?.uid != item.userId) {
      throw StateError('Account changed; this report remains queued');
    }
    // 4. Update the Firestore report
    final reportData = {
      'pestName': result.pestName,
      'scientificName': result.scientificName,
      'riskLevel': result.riskLevel,
      'severity': severity,
      'confidence': (result.confidence * 100).round(),
      'stage': result.lifeStage,
      'crop': result.cropAffected.isNotEmpty ? result.cropAffected : 'Maize',
      'analysis': result.analysis,
      'treatment': result.treatment,
      'annotatedImageUrl': result.annotatedImageUrl,
      'firestoreImageRef': firestoreImageRef,
      if (firestoreImageRef == null) 'imageBase64': imageBase64,
      'farmerId': item.userId,
      'farmerName': item.farmerName ?? 'Farmer',
      'farmId': item.farmId,
      'cycleId': item.cycleId,
      'timestamp': Timestamp.fromMillisecondsSinceEpoch(item.timestamp),
      'location': {
        'lat': item.latitude,
        'lng': item.longitude,
        'areaName': item.areaName,
      },
      'status': 'pending', // update from pending_offline_sync to normal pending
      'isOfflineRecord': false,
      'syncedAt': FieldValue.serverTimestamp(),
    };

    if (item.docId != null && item.docId!.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(item.docId)
          .set({
            ...reportData,
            if (item.farmName != null) 'farmName': item.farmName,
            if (item.fieldId != null) 'fieldId': item.fieldId,
            if (item.fieldName != null) 'fieldName': item.fieldName,
            'lat': item.latitude,
            'lng': item.longitude,
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));
    } else {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(item.id)
          .set({
            ...reportData,
            'farmerId': item.userId,
            'farmId': item.farmId,
            'farmName': item.farmName,
            'fieldId': item.fieldId,
            'fieldName': item.fieldName,
            'cycleId': item.cycleId,
            'timestamp': FieldValue.serverTimestamp(),
            'location': {
              'lat': item.latitude,
              'lng': item.longitude,
              'areaName': item.areaName,
            },
            'lat': item.latitude,
            'lng': item.longitude,
          })
          .timeout(const Duration(seconds: 20));
    }
  }

  /// Remove a specific item from queue manually
  Future<void> removeItem(String id) async {
    _queue.removeWhere((item) => item.id == id);
    await _saveQueue();
  }
}
