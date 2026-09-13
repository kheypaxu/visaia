import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visaia/services/api_service.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Represents a queued offline item waiting for network synchronization.
class QueuedOfflineItem {
  final String id;
  final String? docId;
  final String type; // 'pest_report', 'daily_log', etc.
  final String imagePath;
  final String userId;
  final String? farmId;
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
    this.farmId,
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
        'farmId': farmId,
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
        userId: json['userId'] as String,
        farmId: json['farmId'] as String?,
        cycleId: json['cycleId'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        areaName: json['areaName'] as String? ?? 'Unknown Area',
        timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
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
  List<QueuedOfflineItem> get queue => List.unmodifiable(_queue);

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadQueue();

    // Listen to network reconnection events to trigger auto-sync
    ConnectivityService().onConnectivityRestored.listen((isOnline) {
      if (isOnline && _queue.isNotEmpty) {
        debugPrint('🔄 Online restored: Auto-triggering offline sync queue (${_queue.length} items)');
        syncAll();
      }
    });

    // If already online on startup and has pending items, attempt sync
    if (ConnectivityService().isOnline && _queue.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), () => syncAll());
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
          _queue.add(QueuedOfflineItem.fromJson(decoded));
        } catch (e) {
          debugPrint('Error parsing queued item: $e');
        }
      }
      pendingSyncCount.value = _queue.where((i) => i.status != 'synced').length;
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = _queue.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_queuePrefsKey, stringList);
      pendingSyncCount.value = _queue.where((i) => i.status != 'synced').length;
    } catch (e) {
      debugPrint('Error saving sync queue: $e');
    }
  }

  /// Copies an image file into the app's persistent offline queue directory.
  Future<String> persistOfflineImage(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final queueDir = Directory('${appDir.path}/offline_queue');
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }

    final filename = 'pest_${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split(Platform.pathSeparator).last}';
    final savedFile = await imageFile.copy('${queueDir.path}/$filename');
    return savedFile.path;
  }

  /// Enqueues a pest report recorded offline.
  /// Also creates a document in Firestore (which Firestore persists in its offline cache).
  Future<QueuedOfflineItem> enqueuePestReport({
    required File imageFile,
    required String userId,
    String? farmId,
    String? cycleId,
    required double latitude,
    required double longitude,
    required String areaName,
    String? farmerName,
  }) async {
    await init();

    final persistentPath = await persistOfflineImage(imageFile);
    final itemId = 'offline_rep_${DateTime.now().millisecondsSinceEpoch}';

    // Create a local Firestore report record (Firestore queues this write offline)
    DocumentReference? docRef;
    try {
      docRef = await FirebaseFirestore.instance.collection('reports').add({
        'farmerId': userId,
        'farmerName': farmerName ?? 'Farmer',
        'farmId': farmId,
        'cycleId': cycleId,
        'pestName': 'Queued for AI Analysis',
        'scientificName': 'Pending online sync',
        'severity': 'Moderate',
        'riskLevel': 'Medium',
        'confidence': 0,
        'stage': 'Pending',
        'crop': 'Maize',
        'analysis': 'Recorded offline. Detailed AI analysis and treatment plan will be generated once connected to internet.',
        'treatment': 'Synchronizing with AI server when online...',
        'status': 'pending_offline_sync',
        'timestamp': FieldValue.serverTimestamp(),
        'isOfflineRecord': true,
        'location': {
          'lat': latitude,
          'lng': longitude,
          'areaName': areaName,
        },
      });
    } catch (e) {
      debugPrint('Note: Firestore doc write queued offline: $e');
    }

    final item = QueuedOfflineItem(
      id: itemId,
      docId: docRef?.id,
      type: 'pest_report',
      imagePath: persistentPath,
      userId: userId,
      farmId: farmId,
      cycleId: cycleId,
      latitude: latitude,
      longitude: longitude,
      areaName: areaName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _queue.add(item);
    await _saveQueue();

    debugPrint('📦 Pest report queued for offline sync (ID: $itemId)');
    return item;
  }

  /// Synchronizes all queued offline items with the AI backend and Firestore.
  Future<void> syncAll() async {
    if (isSyncing.value) return;
    if (!ConnectivityService().isOnline) {
      debugPrint('Cannot sync: Device is currently offline.');
      return;
    }

    final pendingItems = _queue.where((i) => i.status != 'synced').toList();
    if (pendingItems.isEmpty) return;

    isSyncing.value = true;
    syncStatusMessage.value = 'Syncing ${pendingItems.length} offline item(s)...';

    int successCount = 0;

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
    }

    // Clean up successfully synced items older than 1 hour or remove from list
    _queue.removeWhere((item) => item.status == 'synced');
    await _saveQueue();

    isSyncing.value = false;
    syncStatusMessage.value = successCount > 0
        ? 'Successfully synced $successCount offline report(s)!'
        : null;

    debugPrint('✅ Sync finished: $successCount synced successfully.');
  }

  Future<void> _processPestReportItem(QueuedOfflineItem item) async {
    final imageFile = File(item.imagePath);
    if (!await imageFile.exists()) {
      throw Exception('Queued image file not found on device');
    }

    // 1. Send image to AI backend
    final result = await ApiService.sendImage(imageFile);

    // 2. Compress image for Firestore document storage if cycle is present
    String? firestoreImageRef;
    try {
      Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 640,
        minHeight: 640,
        quality: 45,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes != null && item.cycleId != null && item.cycleId!.isNotEmpty) {
        final encoded = base64Encode(compressedBytes);
        final imgRef = FirebaseFirestore.instance
            .collection('users')
            .doc(item.userId)
            .collection('cycles')
            .doc(item.cycleId)
            .collection('images')
            .doc();

        await imgRef.set({
          'data': encoded,
          'contentType': 'image/jpeg',
          'category': 'pest_report',
          'createdAt': FieldValue.serverTimestamp(),
        });
        firestoreImageRef = 'firestore-image://${imgRef.path}';
      }
    } catch (e) {
      debugPrint('Warning: Could not compress/store Firestore image ref: $e');
    }

    // 3. Map severity
    final risk = result.riskLevel.toLowerCase();
    final severity = (risk == 'high' || risk == 'critical' || risk == 'severe')
        ? 'High'
        : (risk == 'medium' || risk == 'moderate')
            ? 'Medium'
            : 'Low';

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
      'status': 'pending', // update from pending_offline_sync to normal pending
      'isOfflineRecord': false,
      'syncedAt': FieldValue.serverTimestamp(),
    };

    if (item.docId != null && item.docId!.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(item.docId)
          .set(reportData, SetOptions(merge: true));
    } else {
      await FirebaseFirestore.instance.collection('reports').add({
        ...reportData,
        'farmerId': item.userId,
        'farmId': item.farmId,
        'cycleId': item.cycleId,
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'lat': item.latitude,
          'lng': item.longitude,
          'areaName': item.areaName,
        },
      });
    }

    // Clean up local temp file
    try {
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (_) {}
  }

  /// Remove a specific item from queue manually
  Future<void> removeItem(String id) async {
    _queue.removeWhere((item) => item.id == id);
    await _saveQueue();
  }
}
