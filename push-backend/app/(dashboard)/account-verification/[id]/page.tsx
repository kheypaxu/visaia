'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { useRouter, useParams } from 'next/navigation';
import {
  HiOutlineEye,
  HiOutlineDownload,
  HiOutlineTrash,
  HiOutlineX,
} from 'react-icons/hi';
import {
  HiOutlineChevronLeft,
  HiCheckCircle,
  HiOutlineClock,
  HiOutlineExclamationCircle,
  HiOutlineDocumentText,
} from 'react-icons/hi2';
import { auth, db } from '@/src/config/firebase';
import {
  doc,
  getDoc,
  collection,
  getDocs,
  updateDoc,
} from 'firebase/firestore';
import { dateStamp, exportPdf, safeFilename } from '@/src/utils/exportUtils';
import { useToast } from '@/src/context/ToastContext';
import {
  FarmerProfileAvatar,
  FarmerIdDocuments,
} from '@/app/components/FarmerIdentity';

/* ------------------------------------------------------------------ */
/*  Types                                                              */
/* ------------------------------------------------------------------ */

interface FarmerData {
  id?: string;
  fullName?: string;
  firstName?: string;
  middleName?: string;
  lastName?: string;
  rsbsaId?: string;
  isNonRsbsa?: boolean;
  email?: string;
  sex?: string;
  birthdate?: string;
  profileImage?: string;
  farmerIdImage?: string;
  farmerIdImageBack?: string;
  farmerIdFileName?: string;
  status?: string;
  rejectionReason?: string;
  rejectedAt?: string;
  createdAt?: { toDate: () => Date };
  farmSize?: number;
}

interface FarmRecord {
  id: string;
  name?: string;
  acres?: number;
  boundaries?: unknown[];
  createdAt?: { _seconds?: number };
}

interface FieldRecord {
  id: string;
  name?: string;
  acres?: number;
  crop?: string;
  boundaries?: unknown[];
}

interface CycleRecord {
  id: string;
  cycleName?: string;
  isCompleted?: boolean;
  status?: string;
  cropType?: string;
  cropVariety?: string;
  plantingDate?: { _seconds?: number };
  harvestDate?: { _seconds?: number };
  area?: string;
  totalYield?: string;
  isPreviousCycle?: boolean;
}

interface DocRecord {
  id: number;
  title: string;
  type: string;
  size: string;
  uploaded: string;
  expires: string;
  status: string;
  adminNote: string | null;
}

type DocTab = 'All Documents' | 'Approved' | 'Pending' | 'Rejected';

/* ------------------------------------------------------------------ */
/*  Constants                                                          */
/* ------------------------------------------------------------------ */

const DOC_TABS: DocTab[] = [
  'All Documents',
  'Approved',
  'Pending',
  'Rejected',
];

/* ------------------------------------------------------------------ */
/*  Component                                                          *//* ------------------------------------------------------------------ */

const FarmersProfile: React.FC = () => {
  const router = useRouter();
  const params = useParams();
  const id = params?.id as string;
  const toast = useToast();

  /* ---- state ---- */
  const [farmer, setFarmer] = useState<FarmerData | null>(null);
  const [farms, setFarms] = useState<FarmRecord[]>([]);
  const [fields, setFields] = useState<FieldRecord[]>([]);
  const [cycles, setCycles] = useState<CycleRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeDocTab, setActiveDocTab] = useState<DocTab>('All Documents');

  const [documents, setDocuments] = useState<DocRecord[]>([
    {
      id: 1,
      title: 'Land Certificate',
      type: 'Business License',
      size: '2.4 MB',
      uploaded: '12/09/2025',
      expires: '12/31/2025',
      status: 'Approved',
      adminNote: null,
    },
    {
      id: 2,
      title: "National's ID",
      type: 'Insurance Certificate',
      size: '3.2 MB',
      uploaded: '12/09/2025',
      expires: '12/31/2025',
      status: 'Pending',
      adminNote: null,
    },
    {
      id: 3,
      title: 'DA Permit',
      type: 'Tax Certificate',
      size: '1.8 MB',
      uploaded: '12/09/2025',
      expires: '12/31/2025',
      status: 'Rejected',
      adminNote:
        'Document is unclear. Please upload a higher quality scan.',
    },
  ]);

  /* ─── helpers ─────────────────────────────────────────────── */

  const calculateAge = (birthdate?: string): number | null => {
    if (!birthdate) return null;
    const b = new Date(birthdate);
    const now = new Date();
    let age = now.getFullYear() - b.getFullYear();
    const m = now.getMonth() - b.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < b.getDate())) age--;
    return age;
  };

  const parseName = (
    fullName?: string
  ): { first: string; last: string } => {
    if (!fullName) return { first: 'N/A', last: 'N/A' };
    const parts = fullName.trim().split(' ');
    if (parts.length === 1) return { first: parts[0], last: 'N/A' };
    const last = parts.pop()!;
    return { first: parts.join(' '), last };
  };

  const fmtDate = (d?: string): string => {
    if (!d) return 'N/A';
    return new Date(d).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  const fmtTimestamp = (ts?: { toDate: () => Date }): string => {
    if (!ts?.toDate) return 'N/A';
    return ts.toDate().toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  const fmtSeconds = (s?: number): string =>
    s ? new Date(s * 1000).toLocaleDateString() : 'Unknown date';

  const displayStatus = (s?: string): string => {
    if (!s) return 'N/A';
    return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
  };

  const badgeCls = (status?: string): string => {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'verified':
        return 'bg-[#10B981] text-white';
      case 'pending':
      case 'active':
        return 'bg-orange-400 text-white';
      case 'rejected':
        return 'bg-red-500 text-white';
      case 'completed':
        return 'bg-green-600 text-white';
      default:
        return 'bg-slate-400 text-white';
    }
  };

  /* ─── derived ─────────────────────────────────────────────── */

  const { first: firstName, last: lastName } = useMemo(
    () => parseName(farmer?.fullName),
    [farmer?.fullName]
  );
  const age = useMemo(() => calculateAge(farmer?.birthdate), [farmer?.birthdate]);
  const totalFarmSize = useMemo(
    () => farms.reduce((t, f) => t + (f.acres || 0), 0),
    [farms]
  );
  const activeCycles = useMemo(
    () =>
      cycles.filter(
        (c) =>
          c.status?.toLowerCase() === 'active' || c.isCompleted === false
      ),
    [cycles]
  );
  const completedCycles = useMemo(
    () =>
      cycles.filter(
        (c) =>
          c.status?.toLowerCase() === 'completed' || c.isCompleted === true
      ),
    [cycles]
  );
  const filteredDocs = useMemo(
    () =>
      documents.filter(
        (d) => activeDocTab === 'All Documents' || d.status === activeDocTab
      ),
    [documents, activeDocTab]
  );

  /* ─── firestore fetch ─────────────────────────────────────── */

  useEffect(() => {
    if (!id) return;
    let cancelled = false;

    const fetchAll = async () => {
      setLoading(true);
      try {
        const fSnap = await getDoc(doc(db, 'farmers', id));
        if (!cancelled && fSnap.exists())
          setFarmer({ id: fSnap.id, ...fSnap.data() } as FarmerData);

        const uSnap = await getDoc(doc(db, 'users', id));
        if (!cancelled && uSnap.exists()) {
          const u = uSnap.data();
          if (u.farms) setFarms(u.farms as FarmRecord[]);
          if (u.fields) setFields(u.fields as FieldRecord[]);
        }

        const cSnap = await getDocs(collection(db, 'users', id, 'cycles'));
        if (!cancelled)
          setCycles(
            cSnap.docs.map((d) => ({ id: d.id, ...d.data() } as CycleRecord))
          );

        const fmSnap = await getDocs(collection(db, 'users', id, 'farms'));
        if (!cancelled && !fmSnap.empty)
          setFarms(
            fmSnap.docs.map((d) => ({ id: d.id, ...d.data() } as FarmRecord))
          );

        const fdSnap = await getDocs(collection(db, 'users', id, 'fields'));
        if (!cancelled && !fdSnap.empty)
          setFields(
            fdSnap.docs.map((d) => ({ id: d.id, ...d.data() } as FieldRecord))
          );
      } catch (err) {
        console.error('Fetch error:', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    fetchAll();
    return () => {
      cancelled = true;
    };
  }, [id]);

  /* ─── actions ─────────────────────────────────────────────── */

  const handleVerify = async () => {
    if (!farmer) return;
    try {
      const token = await auth.currentUser?.getIdToken();
      if (!token) throw new Error('Please sign in again before verifying a farmer.');
      const response = await fetch('/api/notifications/account-approved', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ farmerId: id }),
      });
      if (!response.ok) throw new Error('Unable to verify farmer. Please try again.');
      setFarmer({ ...farmer, status: 'verified' });
      toast.success('Farmer account verified successfully!');
      router.push('/account-verification');
    } catch (err: unknown) {
      const e = err as { code?: string; message?: string };
      if (e.code === 'permission-denied') toast.error('Permission denied to verify farmer.');
      else toast.error(`Failed: ${e.message || 'Unknown error'}`);
    }
  };

  const handleReject = async () => {
    const reason = window.prompt('Please provide a reason for rejecting this farmer application:', farmer?.rejectionReason || 'Submitted identity documentation requires correction or re-submission.');
    if (reason === null) return;
    
    try {
      await updateDoc(doc(db, 'farmers', id), { 
        status: 'rejected',
        rejectionReason: reason.trim() || 'Application rejected by LGU-MAO Personnel.',
        rejectedAt: new Date().toISOString(),
      });
      setFarmer(prev => prev ? { ...prev, status: 'rejected', rejectionReason: reason.trim() || 'Application rejected by LGU-MAO Personnel.' } : null);
      console.log(`✅ Farmer ${id} rejected successfully`);
      toast.success('Farmer application rejected.');
      router.push('/account-verification');
    } catch (error) {
      console.error('❌ Error rejecting farmer:', error);
      toast.error('Failed to reject farmer. Please try again.');
    }
  };

  const handleDeleteDoc = (docId: number) => {
    if (window.confirm('Delete this document?'))
      setDocuments((prev) => prev.filter((d) => d.id !== docId));
  };

  const handleExport = () => {
    const headers = ['Title', 'Type', 'Size', 'Uploaded', 'Expires', 'Status'];
    const rows = documents.map((d) => [d.title, d.type, d.size, d.uploaded, d.expires, d.status]);
    exportPdf({
      filename: `VISAIA_Documents_${safeFilename(farmer?.rsbsaId || String(id))}_${dateStamp()}.pdf`,
      title: 'Farmer Document Register',
      subtitle: farmer?.fullName || farmer?.rsbsaId || 'Account verification record',
      headers,
      rows,
      metadata: [{ label: 'RSBSA ID', value: farmer?.rsbsaId || String(id) }],
    });
  };

  /* ─── loading ─────────────────────────────────────────────── */

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[60vh] bg-[#F8FAFC] dark:bg-[#0B1120]">
        <div className="text-center space-y-4">
          <div className="mx-auto h-12 w-12 animate-spin rounded-full border-[3px] border-slate-200 dark:border-slate-800 border-t-[#10B981]" />
          <p className="text-sm font-medium text-slate-500 dark:text-slate-400">
            Loading farmer profile…
          </p>
        </div>
      </div>
    );
  }

  /* ================================================================ */
  /*  RENDER                                                           */
  /* ================================================================ */
  return (
    <div className="bg-[#F8FAFC] dark:bg-[#0B1120] min-h-screen font-['Inter',system-ui,sans-serif]">
      <div className="max-w-[1360px] mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-8 space-y-6">
        {/* ══════════════════════════════════════════════════════
            ACTION STICKY HEADER STRIP
        ══════════════════════════════════════════════════════ */}
        <div className="sticky top-0 z-30 bg-[#F8FAFC]/80 dark:bg-[#0B1120]/80 backdrop-blur-md -mx-4 sm:-mx-6 lg:-mx-8 px-4 sm:px-6 lg:px-8 pt-2 pb-4 border-b border-slate-200/60 dark:border-slate-800">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            {/* left anchor */}
            <div className="flex items-center gap-3 min-w-0">
              <button
                onClick={() => router.push('/account-verification')}
                className="w-9 h-9 flex items-center justify-center rounded-full border border-slate-300 dark:border-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors flex-shrink-0"
                aria-label="Go back"
              >
                <HiOutlineChevronLeft className="text-xl" />
              </button>
              <h1 className="text-lg sm:text-xl font-extrabold text-slate-900 dark:text-white truncate">
                Farmer&apos;s Profile
                <span className="font-semibold text-slate-400 dark:text-slate-500 ml-2">
                  {farmer?.fullName || id}
                </span>
              </h1>
            </div>

            {/* right cluster */}
            <div className="flex items-center gap-2.5 flex-shrink-0 flex-wrap">
              <button
                onClick={handleReject}
                className="px-5 py-2.5 rounded-xl text-sm font-bold text-white bg-slate-500 hover:bg-slate-600 dark:bg-slate-700 dark:hover:bg-slate-600 transition-colors"
              >
                Reject
              </button>

              <button
                onClick={handleVerify}
                disabled={farmer?.status === 'verified'}
                className={`px-6 py-2.5 rounded-xl text-sm font-bold text-white transition-colors ${
                  farmer?.status === 'verified'
                    ? 'bg-slate-300 dark:bg-slate-800 dark:text-slate-500 cursor-not-allowed'
                    : 'bg-[#10B981] hover:bg-emerald-600 shadow-sm shadow-emerald-600/20'
                }`}
              >
                {farmer?.status === 'verified' ? 'Verified' : 'Verify'}
              </button>
            </div>
          </div>
        </div>

        {/* ══════════════════════════════════════════════════════
            SECTION 1 — PERSONAL IDENTITY CARD
        ══════════════════════════════════════════════════════ */}
        <section className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-100 dark:border-slate-800 shadow-sm overflow-hidden">
          <div className="p-6 lg:p-8 flex flex-col md:flex-row gap-8 lg:gap-10">
            {/* left profile photo anchor */}
            <div className="w-full md:w-60 lg:w-64 flex-shrink-0 flex flex-col items-center gap-4">
              <div className="w-full max-w-[220px] aspect-square rounded-3xl bg-slate-100 dark:bg-slate-800 border border-slate-200/60 dark:border-slate-700 flex items-center justify-center overflow-hidden">
                <FarmerProfileAvatar
                  name={farmer?.fullName}
                  profileImage={farmer?.profileImage}
                  size="xl"
                />
              </div>
              <div className="text-center">
                <p className="text-[10px] font-bold uppercase tracking-widest text-slate-400 dark:text-slate-500">
                  Profile Photo
                </p>
                <p className="text-sm font-bold text-slate-700 dark:text-slate-200 mt-0.5 truncate">
                  {farmer?.fullName || 'Unnamed Farmer'}
                </p>
                {farmer?.profileImage ? (
                  <p className="text-[11px] text-emerald-600 dark:text-emerald-400 font-semibold">
                    Uploaded by farmer
                  </p>
                ) : (
                  <p className="text-[11px] text-slate-400 dark:text-slate-500">
                    Showing initials
                  </p>
                )}
              </div>
            </div>

            {/* right information grid */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-3 mb-6">
                <h2 className="text-xl font-extrabold text-[#10B981] dark:text-emerald-400">
                  Farmer&apos;s Personal Information
                </h2>
                {farmer?.status && (
                  <span
                    className={`text-[10px] font-bold px-3 py-1 rounded-full uppercase tracking-wider ${badgeCls(farmer.status)}`}
                  >
                    {displayStatus(farmer.status)}
                  </span>
                )}
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-7">
                {(
                  [
                    ['Full Name', farmer?.fullName || 'N/A'],
                    ['First Name', firstName],
                    ['Middle Name', farmer?.middleName || 'N/A'],
                    ['Last Name', lastName],
                    ['Registration Path', !farmer?.rsbsaId || farmer?.rsbsaId === 'Non-RSBSA' ? 'Non-RSBSA Path' : 'RSBSA Registered'],
                    ['RSBSA ID', !farmer?.rsbsaId || farmer?.rsbsaId === 'Non-RSBSA' ? 'None (Non-RSBSA Farmer)' : farmer.rsbsaId],
                    ['Account Verification', displayStatus(farmer?.status)],
                    ['Email Address', farmer?.email || 'N/A'],
                    ['Sex', farmer?.sex || 'N/A'],
                    ['Birthdate', fmtDate(farmer?.birthdate)],
                    ['Calculated Age', age ? `${age} years old` : 'N/A'],
                  ] as const
                ).map(([label, value]) => (
                  <div key={label}>
                    <p className="text-[11px] font-semibold text-slate-400 dark:text-slate-500 tracking-wide uppercase mb-1">
                      {label}
                    </p>
                    <p
                      className={`text-base font-bold text-slate-900 dark:text-white leading-tight break-words ${
                        label === 'RSBSA ID' && value !== 'None (Non-RSBSA Farmer)' ? 'font-mono text-emerald-700 dark:text-emerald-400' : ''
                      }`}
                    >
                      {value}
                    </p>
                  </div>
                ))}

                {/* full-width member since */}
                <div className="sm:col-span-2 lg:col-span-3">
                  <p className="text-[11px] font-semibold text-slate-400 dark:text-slate-500 tracking-wide uppercase mb-1">
                    Member Since
                  </p>
                  <p className="text-base font-bold text-slate-900 dark:text-white">
                    {fmtTimestamp(farmer?.createdAt)}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ══════════════════════════════════════════════════════
            SECTION 1.5 — IDENTITY DOCUMENTS (FRONT & BACK)
        ══════════════════════════════════════════════════════ */}
        <section className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-100 dark:border-slate-800 shadow-sm p-6 lg:p-8 space-y-5">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
            <h2 className="text-xl font-extrabold text-[#10B981] dark:text-emerald-400">
              Identity Documents
            </h2>
            <p className="text-xs text-slate-400 dark:text-slate-500 font-medium">
              Click an image to open it full screen — scroll to zoom, drag to pan.
            </p>
          </div>

          <FarmerIdDocuments
            ids={{
              front: farmer?.farmerIdImage,
              back: farmer?.farmerIdImageBack,
            }}
            name={farmer?.fullName}
          />

          <div className="flex flex-wrap items-center gap-x-5 gap-y-2 text-[11px] text-slate-500 dark:text-slate-400">
            <span className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-500" />
              Front uploaded
            </span>
            <span className="flex items-center gap-1.5">
              <span
                className={`w-2 h-2 rounded-full ${
                  farmer?.farmerIdImageBack ? 'bg-emerald-500' : 'bg-slate-300 dark:bg-slate-600'
                }`}
              />
              Back {farmer?.farmerIdImageBack ? 'uploaded' : 'not uploaded yet'}
            </span>
          </div>
        </section>

        {/* ══════════════════════════════════════════════════════
            SECTION 2 — FARM METRICS & CROPPING CYCLE DOSSIER
        ══════════════════════════════════════════════════════ */}
        <section className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-100 dark:border-slate-800 shadow-sm p-6 lg:p-8 space-y-8">
          <h2 className="text-xl font-extrabold text-[#10B981] dark:text-emerald-400">
            Farm Metrics &amp; Cropping Dossier
          </h2>

          {/* ── analytical summary deck ── */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {(
              [
                ['Total Farms', farms.length],
                ['Total Fields', fields.length],
                ['Estimated Farm Size', `${totalFarmSize.toFixed(2)} ha`],
                [
                  'Cycles',
                  `${cycles.length}`,
                  `${activeCycles.length} active, ${completedCycles.length} completed`,
                ],
              ] as const
            ).map(([label, primary, sub], i) => (
              <div key={label} className="bg-green-50 dark:bg-emerald-950/40 rounded-xl p-4 lg:p-5 border border-transparent dark:border-emerald-900/30">
                <p className="text-xs font-semibold text-slate-600 dark:text-slate-300 mb-1">
                  {label}
                </p>
                <p className="text-2xl font-extrabold text-[#10B981] dark:text-emerald-400 leading-none">
                  {primary}
                </p>
                {sub && (
                  <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-1.5">{sub}</p>
                )}
              </div>
            ))}
          </div>

          {/* ── registered farms ── */}
          {farms.length > 0 && (
            <div>
              <h3 className="text-base font-bold text-slate-900 dark:text-white mb-3">
                Registered Farms
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {farms.map((farm) => (
                  <div
                    key={farm.id}
                    className="border border-slate-200/60 dark:border-slate-800 bg-slate-50/40 dark:bg-slate-800/30 rounded-xl p-4 space-y-2"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <h4 className="font-bold text-slate-900 dark:text-white text-sm">
                        {farm.name || 'Unnamed Farm'}
                      </h4>
                      {farm.acres != null && (
                        <span className="text-xs font-bold text-[#10B981] dark:text-emerald-400 bg-green-50 dark:bg-emerald-950/60 px-2 py-0.5 rounded-md flex-shrink-0">
                          {farm.acres.toFixed(2)} ha
                        </span>
                      )}
                    </div>
                    {farm.boundaries && farm.boundaries.length > 0 && (
                      <p className="text-[11px] text-slate-400 dark:text-slate-500">
                        {farm.boundaries.length} polygon boundary points
                      </p>
                    )}
                    <p className="text-[11px] text-slate-400 dark:text-slate-500">
                      Created: {fmtSeconds(farm.createdAt?._seconds)}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ── registered fields ── */}
          {fields.length > 0 && (
            <div>
              <h3 className="text-base font-bold text-slate-900 dark:text-white mb-3">
                Registered Fields
              </h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {fields.map((field) => (
                  <div
                    key={field.id}
                    className="border border-slate-200/60 dark:border-slate-800 bg-slate-50/40 dark:bg-slate-800/30 rounded-xl p-4 space-y-1.5"
                  >
                    <h4 className="font-bold text-slate-900 dark:text-white text-sm">
                      {field.name || 'Unnamed Field'}
                    </h4>
                    {field.crop && (
                      <p className="text-xs text-slate-600 dark:text-slate-300">
                        Crop: <span className="font-semibold text-slate-800 dark:text-slate-200">{field.crop}</span>
                      </p>
                    )}
                    {field.acres != null && field.acres > 0 && (
                      <p className="text-xs text-slate-600 dark:text-slate-300">
                        Size: {field.acres.toFixed(2)} ha
                      </p>
                    )}
                    {field.boundaries && field.boundaries.length > 0 && (
                      <p className="text-[11px] text-slate-400 dark:text-slate-500">
                        {field.boundaries.length} boundary vertices
                      </p>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ── cropping cycles ── */}
          {cycles.length > 0 && (
            <div>
              <h3 className="text-base font-bold text-slate-900 dark:text-white mb-3">
                Cropping Cycles
              </h3>
              <div className="space-y-3">
                {cycles.slice(0, 6).map((cycle) => {
                  const done =
                    cycle.status?.toLowerCase() === 'completed' ||
                    cycle.isCompleted === true;
                  return (
                    <div
                      key={cycle.id}
                      className="border border-slate-200/60 dark:border-slate-800 bg-slate-50/40 dark:bg-slate-800/30 rounded-xl p-4"
                    >
                      <div className="flex items-center justify-between mb-3">
                        <h4 className="font-bold text-slate-900 dark:text-white text-sm">
                          {cycle.cycleName || 'Unnamed Cycle'}
                        </h4>
                        <span
                          className={`text-[10px] font-bold px-2.5 py-1 rounded-full uppercase tracking-wider ${
                            done
                              ? 'bg-green-600 text-white'
                              : 'bg-orange-400 text-white'
                          }`}
                        >
                          {done ? 'Completed' : 'Active'}
                        </span>
                      </div>
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                        {cycle.cropVariety && (
                          <div>
                            <p className="text-slate-400 dark:text-slate-500 mb-0.5">Variety</p>
                            <p className="font-semibold text-slate-800 dark:text-slate-200">
                              {cycle.cropVariety}
                            </p>
                          </div>
                        )}
                        {cycle.plantingDate?._seconds && (
                          <div>
                            <p className="text-slate-400 dark:text-slate-500 mb-0.5">Planting Date</p>
                            <p className="font-semibold text-slate-800 dark:text-slate-200">
                              {fmtSeconds(cycle.plantingDate._seconds)}
                            </p>
                          </div>
                        )}
                        {cycle.harvestDate?._seconds && (
                          <div>
                            <p className="text-slate-400 dark:text-slate-500 mb-0.5">Harvest Date</p>
                            <p className="font-semibold text-slate-800 dark:text-slate-200">
                              {fmtSeconds(cycle.harvestDate._seconds)}
                            </p>
                          </div>
                        )}
                        {cycle.totalYield && (
                          <div>
                            <p className="text-slate-400 dark:text-slate-500 mb-0.5">Total Yield</p>
                            <p className="font-semibold text-slate-800 dark:text-slate-200">
                              {cycle.totalYield} units
                            </p>
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })}
                {cycles.length > 6 && (
                  <p className="text-center text-xs text-slate-400 dark:text-slate-500 pt-1">
                    + {cycles.length - 6} more cycles
                  </p>
                )}
              </div>
            </div>
          )}

          {/* empty */}
          {farms.length === 0 &&
            fields.length === 0 &&
            cycles.length === 0 && (
              <div className="flex flex-col items-center justify-center py-14 text-center">
                <div className="w-14 h-14 rounded-2xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center mb-4">
                  <HiOutlineDocumentText className="text-slate-300 dark:text-slate-600 text-2xl" />
                </div>
                <p className="text-sm font-semibold text-slate-600 dark:text-slate-300">
                  No farm information available
                </p>
                <p className="text-xs text-slate-400 dark:text-slate-500 mt-1">
                  Farm data will appear here once registered.
                </p>
              </div>
            )}
        </section>
      </div>
    </div>
  );
};

export default FarmersProfile;
