import 'package:flutter/material.dart';

enum TaskStatus { active, future, completed }

class PestDetection {
  final String id;
  final String label;
  final double confidence;
  final DateTime timestamp;
  final String imageUrl;

  PestDetection({
    required this.id,
    required this.label,
    required this.confidence,
    required this.timestamp,
    required this.imageUrl,
  });
}

class MonitoringTask {
  final String id;
  String title;
  TaskStatus status;
  DateTime? dueDate;

  MonitoringTask({
    required this.id,
    required this.title,
    this.status = TaskStatus.future,
    this.dueDate,
  });
}

class Crop {
  final String name;
  final IconData icon;
  final Color color;

  const Crop({
    required this.name,
    this.icon = Icons.eco,
    this.color = const Color(0xFF8DBA60),
  });

  static const Crop unknown = Crop(
    name: 'Empty',
    icon: Icons.add,
    color: Colors.grey,
  );
}

class FarmArea {
  final int id;
  String name;
  Crop crop;
  bool isAffected;
  double health; // 0.0 to 1.0
  double growthProgress; // 0.0 to 1.0
  DateTime? plantingDate;
  double hectares; // Size of the area in hectares
  List<MonitoringTask> tasks;
  List<PestDetection> detectionHistory;

  FarmArea({
    required this.id,
    this.name = '',
    this.crop = Crop.unknown,
    this.isAffected = false,
    this.health = 1.0,
    this.growthProgress = 0.0,
    this.plantingDate,
    this.hectares = 0.0, // Default to 0.0 hectares
    List<MonitoringTask>? tasks,
    List<PestDetection>? detectionHistory,
  }) : tasks = tasks ?? [],
       detectionHistory = detectionHistory ?? [];

  /// Determines if the farm area should be displayed as a large tile.
  /// An area is considered large if it is greater than 2.0 hectares.
  bool get isLarge => hectares > 2.0;

  bool get isPlanted => crop != Crop.unknown;
}