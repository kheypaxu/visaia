const { test } = require('node:test');
const assert = require('node:assert/strict');
const { reminderPeriod, manilaDay, scoutingComplete, loggedToday } = require('./src/policy.ts');
const cycle = {
  plantingDate: new Date('2026-10-01T08:00:00+08:00'),
  harvestDate: new Date('2027-01-01T08:00:00+08:00'),
};
test('Philippine date changes independently of UTC', () => {
  assert.equal(manilaDay(new Date('2026-10-23T23:00:00Z')), '2026-10-24');
});
test('crop weeks match existing Monitoring day-7 and day-8 boundaries', () => {
  assert.equal(reminderPeriod(cycle, new Date('2026-10-08T08:00:00+08:00')).week, 1);
  assert.equal(reminderPeriod(cycle, new Date('2026-10-09T08:00:00+08:00')).week, 2);
});
test('daily log day IDs use planting calendar date, even before planting time of day', () => {
  assert.equal(reminderPeriod(cycle, new Date('2026-10-02T07:00:00+08:00')).dayId, 'day_02');
});
test('do not remind before planting or after actual completion', () => {
  const now = new Date('2026-10-24T07:00:00+08:00');
  for (const completion of [{ isCompleted: true }, { status: 'harvested' }, { actualHarvestDate: now }, { harvestCompletedAt: now }]) {
    assert.equal(reminderPeriod({ ...cycle, ...completion }, now), null);
  }
  assert.equal(reminderPeriod(cycle, new Date('2026-09-24')), null);
});
test('expected harvest date alone does not complete a cycle', () => {
  assert.ok(reminderPeriod(cycle, new Date('2027-01-10T07:00:00+08:00')));
});
test('all five stations are required; support legacy station counts', () => {
  assert.equal(scoutingComplete({ stations: [{ completed: true }] }), false);
  assert.equal(scoutingComplete({ stations: Array(5).fill({ completed: true }) }), true);
  assert.equal(scoutingComplete({ stations: [...Array(4).fill({ completed: true }), { completed: false }] }), false);
  assert.equal(scoutingComplete({ completedStations: 5 }), true);
  assert.equal(scoutingComplete({}), false);
});
test('only a non-scheduled log for today suppresses the daily reminder', () => {
  const now = new Date('2026-10-24T07:00:00+08:00');
  assert.equal(loggedToday({ date: now, status: 'completed' }, now), true);
  assert.equal(loggedToday({ date: now, status: 'in_progress' }, now), true);
  assert.equal(loggedToday({ date: now, status: 'scheduled' }, now), false);
  assert.equal(loggedToday({ date: now, isScheduled: true }, now), false);
  assert.equal(loggedToday({ date: new Date('2026-10-23T07:00:00+08:00') }, now), false);
});
