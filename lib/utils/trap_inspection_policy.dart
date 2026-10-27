/// Calendar-day indexing avoids assigning midnight inspections to the prior day
/// when planting timestamps include a time of day.
int trapInspectionDayIndex(DateTime inspection, DateTime planting) {
  DateTime day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
  return day(inspection).difference(day(planting)).inDays;
}

/// A historical entry belongs in history but must not replace a newer summary.
bool shouldUpdateTrapInspection(DateTime inspection, DateTime? previous) =>
    previous == null || !inspection.isBefore(previous);
