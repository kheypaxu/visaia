// Pure policies shared by the cron handler and its tests. No paid Firebase APIs.
export function dateValue(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (value && typeof value === 'object' && 'toDate' in value) {
    return (value as { toDate(): Date }).toDate();
  }
  if (typeof value === 'string') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  return null;
}
export function manilaDay(date: Date): string {
  return new Date(date.getTime() + 8 * 3600000).toISOString().slice(0, 10);
}
export function reminderPeriod(cycle: Record<string, unknown>, now: Date) {
  const planting = dateValue(cycle.plantingDate);
  if (!planting || now < planting || cycle.isCompleted === true ||
      ['completed', 'harvested', 'archived', 'deleted', 'cancelled'].includes(String(cycle.status).toLowerCase()) ||
      cycle.harvestCompletedAt || cycle.actualHarvestDate) return null;
  const harvest = dateValue(cycle.harvestDate);
  // Match Monitoring's elapsed-day week locks, including the day-7 boundary.
  const totalDays = harvest ? Math.trunc((harvest.getTime() - planting.getTime()) / 86400000) : 0;
  const totalWeeks = Math.max(1, Math.min(52, Math.ceil(totalDays / 7)));
  const elapsed = Math.max(0, Math.min(Math.trunc((now.getTime() - planting.getTime()) / 86400000), Math.max(0, totalDays)));
  const week = Math.max(1, Math.min(totalWeeks, Math.ceil(elapsed / 7)));
  const day = Math.round((Date.parse(manilaDay(now)) - Date.parse(manilaDay(planting))) / 86400000) + 1;
  return { dayId: `day_${String(day).padStart(2, '0')}`, weekId: `week_${week}`, week };
}
export function scoutingComplete(week: Record<string, unknown>) {
  const stations = week.stations;
  return Number(week.completedStations ?? 0) >= 5 ||
    (Array.isArray(stations) && stations.length >= 5 && stations.every(s => s?.completed === true));
}
export function loggedToday(activity: Record<string, unknown>, now: Date) {
  const date = dateValue(activity.date);
  return activity.isScheduled !== true && activity.status !== 'scheduled' &&
    date !== null && manilaDay(date) === manilaDay(now);
}
