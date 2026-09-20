/// Uses the actual submission time until the selected scouting week ends.
/// Weeks are zero-indexed seven-day periods starting on the planting date.
DateTime scoutingReportDate({
  required DateTime plantingDate,
  required int weekIndex,
  required DateTime submittedAt,
}) {
  final nextWeek = DateTime(
    plantingDate.year,
    plantingDate.month,
    plantingDate.day + (weekIndex + 1) * 7,
  );
  return submittedAt.isBefore(nextWeek)
      ? submittedAt
      : nextWeek.subtract(const Duration(microseconds: 1));
}

int scoutingReportDap(DateTime plantingDate, DateTime reportDate) {
  return DateTime.utc(reportDate.year, reportDate.month, reportDate.day)
      .difference(
        DateTime.utc(plantingDate.year, plantingDate.month, plantingDate.day),
      )
      .inDays;
}
