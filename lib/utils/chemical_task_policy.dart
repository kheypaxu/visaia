/// Whether this week's completed scouting qualifies for chemical tasks.
bool isChemicalTaskEligible({
  required String? controlMethod,
  required int? startWeek,
  required int weekNumber,
  required bool isFutureWeek,
  required List<Map<String, dynamic>> stations,
}) {
  if (controlMethod != 'chemical' ||
      startWeek == null ||
      weekNumber < startWeek ||
      isFutureWeek ||
      stations.isEmpty ||
      !stations.every((station) => station['completed'] == true)) {
    return false;
  }
  final inspected = stations.fold<int>(
    0,
    (sum, station) => sum + (station['plantsInspected'] as int? ?? 0),
  );
  final damaged = stations.fold<int>(
    0,
    (sum, station) => sum + (station['damaged'] as int? ?? 0),
  );
  // Matches the existing High/Low clustered-report boundary.
  return inspected > 0 && damaged * 100 >= inspected * 10;
}
