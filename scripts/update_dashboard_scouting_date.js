const fs = require('fs');

const scoutingReportContent = `const DAY = 86400000;
const MANILA_OFFSET = 8 * 60 * 60 * 1000;
type Report = Record<string, unknown>;

export function reportDate(value: unknown): Date | null {
  if (value == null) return null;
  let date: Date;
  if (value instanceof Date) date = value;
  else if (typeof value === 'object' && 'toDate' in value && typeof (value as any).toDate === 'function') date = (value as any).toDate();
  else if (typeof value === 'object' && 'seconds' in value && typeof (value as any).seconds === 'number') date = new Date((value as any).seconds * 1000);
  else if (typeof value === 'string' || typeof value === 'number') date = new Date(value);
  else return null;
  return Number.isFinite(date.getTime()) ? date : null;
}

// Same DAP boundaries and scores as the mobile app's growth_stage.dart.
function growthStage(dap: number) {
  if (dap < 0 || dap > 75) return null;
  if (dap <= 14) return { growthStage: 'Seedling', growthStageScore: 0.2 };
  if (dap <= 29) return { growthStage: 'Early Vegetative', growthStageScore: 0.4 };
  if (dap <= 48) return { growthStage: 'Late Vegetative', growthStageScore: 0.7 };
  if (dap <= 53) return { growthStage: 'Tasseling-Silking', growthStageScore: 1.0 };
  if (dap <= 69) return { growthStage: 'Grain Fill', growthStageScore: 0.6 };
  return { growthStage: 'Maturity', growthStageScore: 0.2 };
}

export function normalizeScoutingReport(data: Report, cyclePlanting?: unknown): Report {
  const cycleInfo = data.cycleInfo as Report | undefined;
  const planting = reportDate(data.plantingDate) || reportDate(cycleInfo?.plantingDate) || reportDate(cyclePlanting);
  const submitted = reportDate(data.submittedAt) || reportDate(data.timestamp) || reportDate(data.createdAt) || reportDate(data.reportDate);
  
  const rawWeek = typeof data.weekNumber === 'number' ? data.weekNumber : NaN;
  const rawDap = typeof data.dap === 'number' ? data.dap : NaN;

  // Resolve target DAP week (Week 1 = Days 0-6, Week 2 = Days 7-13, etc.)
  let week: number | null = null;
  if (Number.isInteger(rawWeek) && rawWeek >= 1 && rawWeek <= 52) {
    week = rawWeek;
  } else if (Number.isInteger(rawDap) && rawDap >= 0) {
    week = Math.floor(rawDap / 7) + 1;
  }

  // Anchor calendar-day arithmetic to the scouting location, not the browser timezone.
  let plantingDay = planting ? Math.floor((planting.getTime() + MANILA_OFFSET) / DAY) : null;
  if (plantingDay === null && submitted && Number.isInteger(rawDap) && rawDap >= 0) {
    plantingDay = Math.floor((submitted.getTime() + MANILA_OFFSET) / DAY) - rawDap;
  }

  let effective: Date | null = null;
  if (plantingDay !== null && week !== null) {
    // The last day of that specific DAP week (23:59:59.999 of the 7th day of that week)
    const nextWeek = (plantingDay + week * 7) * DAY - MANILA_OFFSET;
    effective = new Date(nextWeek - 1);
  } else {
    effective = reportDate(data.reportDate) || submitted;
  }

  let dap: number | null = null;
  if (Number.isInteger(rawDap) && rawDap >= 0 && rawDap <= 75) {
    dap = rawDap;
  } else if (effective && plantingDay !== null) {
    dap = Math.floor((effective.getTime() + MANILA_OFFSET) / DAY) - plantingDay;
  } else if (week !== null) {
    dap = week * 7 - 1;
  }

  const stage = dap === null ? null : growthStage(dap);
  return {
    ...data,
    ...(effective ? { reportDate: effective, timestamp: effective, createdAt: effective } : {}),
    ...(stage ? { dap, ...stage } : {}),
  };
}
`;

const loadScoutingReportContent = `import { doc, getDoc } from 'firebase/firestore';
import { db } from '@/src/config/firebase';
import { normalizeScoutingReport, reportDate } from './scoutingReport';

export async function loadScoutingReport(data: Record<string, unknown>) {
  const cycleInfo = data.cycleInfo as Record<string, unknown> | undefined;
  let planting = data.plantingDate || cycleInfo?.plantingDate;
  const uid = (data.userId || data.farmerId) as string | undefined;
  const cycleId = (data.cycleId || cycleInfo?.cycleId) as string | undefined;

  if (!reportDate(planting) && cycleId) {
    if (uid) {
      try {
        const cycle = await getDoc(doc(db, 'users', uid, 'cycles', cycleId));
        if (cycle.exists()) {
          planting = cycle.data()?.plantingDate;
        }
      } catch (error) {
        console.warn('Could not read user scouting cycle; trying root cycles.', error);
      }
    }
    if (!reportDate(planting)) {
      try {
        const rootCycle = await getDoc(doc(db, 'cycles', cycleId));
        if (rootCycle.exists()) {
          planting = rootCycle.data()?.plantingDate;
        }
      } catch (error) {
        console.warn('Could not read root cycle.', error);
      }
    }
  }
  return normalizeScoutingReport(data, planting);
}
`;

fs.writeFileSync('c:/PROJECTS/visaia-dashboard/src/utils/scoutingReport.ts', scoutingReportContent, 'utf8');
console.log('Successfully updated c:/PROJECTS/visaia-dashboard/src/utils/scoutingReport.ts');

fs.writeFileSync('c:/PROJECTS/visaia-dashboard/src/utils/loadScoutingReport.ts', loadScoutingReportContent, 'utf8');
console.log('Successfully updated c:/PROJECTS/visaia-dashboard/src/utils/loadScoutingReport.ts');
