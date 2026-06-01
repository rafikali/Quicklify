import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { PlansManager, type PlanRow } from './plans-manager';

export const dynamic = 'force-dynamic';

export default async function PlansPage() {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');

  const rows = await loadPlans();
  return (
    <div>
      <div className="flex items-baseline justify-between mb-1">
        <h1 className="text-xl font-semibold">Plans</h1>
        <p className="text-muted text-xs">
          {rows.length} plan{rows.length === 1 ? '' : 's'}
        </p>
      </div>
      <p className="text-muted text-sm mb-6">
        These are the plans shown in the mobile app&apos;s premium screen and
        used to compute subscription expiry when granting premium.
      </p>
      <PlansManager initialPlans={rows} />
    </div>
  );
}

async function loadPlans(): Promise<PlanRow[]> {
  const { db } = firebaseAdmin();
  const snap = await db.collection('plans').get();
  const rows: PlanRow[] = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      name: (data.name as string) ?? d.id,
      durationDays: (data.durationDays as number) ?? 0,
      priceInr: (data.priceInr as number) ?? 0,
      currency: (data.currency as string) ?? 'Rs',
      sortOrder: (data.sortOrder as number) ?? 0,
      active: (data.active as boolean) ?? true,
      popular: (data.popular as boolean) ?? false,
      tagline: (data.tagline as string | null) ?? null,
    };
  });
  rows.sort((a, b) => a.sortOrder - b.sortOrder || a.priceInr - b.priceInr);
  return rows;
}
