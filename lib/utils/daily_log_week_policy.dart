/// Uses the same elapsed-day boundaries as Monitoring's locked weeks.
int currentDailyLogWeek({
  required DateTime plantingDate,
  required DateTime now,
  DateTime? harvestDate,
}) {
  final totalDays = harvestDate?.difference(plantingDate).inDays ?? 0;
  final totalWeeks = (totalDays / 7).ceil().clamp(1, 52);
  final elapsedDays = now.difference(plantingDate).inDays.clamp(
        0,
        totalDays > 0 ? totalDays : 0,
      );
  return (elapsedDays / 7).ceil().clamp(1, totalWeeks);
}
