import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { DevicesManager, type DeviceRow } from './devices-manager';
import { HowToNote } from '@/components/how-to-note';

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

      <HowToNote
        whatToDo={[
          'Recent tab: every device that opened the app recently. Click a device label to drill into its activity timeline (signed-out users only — signed-in ones show under Users).',
          'Banned tab: every currently-banned device. You can unban from here.',
          'Ban by ID tab: if you already have the device fingerprint (from support, audit log, etc.) you can pre-ban a device even before it heart-beats.',
          'To ban: in the Recent tab, click Ban on the row → type a short reason → confirm. Reason is shown to the user on the blackout screen.',
        ]}
        howToVerify={[
          'On the test phone, open the Quicklify app at least once so its fingerprint heart-beats into the Recent list.',
          'In the admin, find the device by its label (e.g. "Pixel 7 · android 14") and click Ban.',
          'On the phone, foreground the app (or relaunch). The blackout screen should appear within ~2 seconds showing your ban reason.',
          'Sign-out / sign-in does NOT bypass the ban (it is keyed by the physical device fingerprint, not by user).',
          'Unban from the Banned tab → next foreground resume the app works normally again.',
        ]}
        tip="Bans are device-keyed, so a banned user reinstalling the app or signing in with a different Google account on the SAME phone is still blocked. Only switching to a different physical device bypasses it."
      />

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
