import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { DevicesManager, type DeviceRow } from './devices-manager';

export const dynamic = 'force-dynamic';

export default async function DevicesPage() {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');

  const [recent, banned] = await Promise.all([
    loadRecent(),
    loadBanned(),
  ]);

  return (
    <div>
      <h1 className="text-xl font-semibold mb-1">Devices</h1>
      <p className="text-muted text-sm mb-6">
        Every install heart-beats here on launch. Ban a device to show the
        blackout screen even when the user is signed out. Takes effect on
        next foreground resume.
      </p>
      <DevicesManager recent={recent} banned={banned} />
    </div>
  );
}

async function loadRecent(): Promise<DeviceRow[]> {
  const { db } = firebaseAdmin();
  const snap = await db
    .collection('device_registry')
    .orderBy('lastSeenAt', 'desc')
    .limit(100)
    .get();
  return snap.docs.map(mapRow);
}

async function loadBanned(): Promise<DeviceRow[]> {
  const { db } = firebaseAdmin();
  const snap = await db
    .collection('device_registry')
    .where('banned', '==', true)
    .limit(200)
    .get();
  return snap.docs.map(mapRow);
}

function mapRow(d: FirebaseFirestore.QueryDocumentSnapshot): DeviceRow {
  const data = d.data();
  return {
    id: d.id,
    label: (data.deviceLabel as string) ?? null,
    platform: (data.platform as string) ?? null,
    lastVersion: (data.lastVersion as string) ?? null,
    lastSeenAt:
      typeof data.lastSeenAt?.toMillis === 'function'
        ? data.lastSeenAt.toMillis()
        : null,
    firstSeenAt:
      typeof data.firstSeenAt?.toMillis === 'function'
        ? data.firstSeenAt.toMillis()
        : null,
    lastUserUid: (data.lastUserUid as string | null) ?? null,
    banned: (data.banned as boolean) ?? false,
    banReason: (data.banReason as string | null) ?? null,
    bannedAt:
      typeof data.bannedAt?.toMillis === 'function'
        ? data.bannedAt.toMillis()
        : null,
  };
}
