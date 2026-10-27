/// Evidence verification and the farmer's station completion are separate steps.
bool isScoutingStationCompleted(Object? station) =>
    station is Map && station['completed'] == true;

bool isScoutingWeekCompleted(Map<String, dynamic> week) {
  final completedCount = week['completedStations'];
  final stations = week['stations'];
  return week['status'] == 'completed' ||
      week['isCompleted'] == true ||
      (completedCount is num && completedCount >= 5) ||
      (stations is List &&
          stations.isNotEmpty &&
          stations.every(isScoutingStationCompleted));
}

/// Adding an observation invalidates any previous verification. Keep all saved
/// evidence so Monitoring can review it without asking for another upload.
void requireAssignedObservationVerification(Map<String, dynamic> station) {
  station['verificationRequired'] = true;
  station['verificationCompleted'] = false;
}
