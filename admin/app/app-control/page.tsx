import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { AppControlForm, type AppConfigRow } from './app-control-form';

export const dynamic = 'force-dynamic';

const DEFAULTS: AppConfigRow = {
  minRequiredVersion: '0.0.0',
  latestVersion: '0.0.0',
  apkUrl: 'https://quicklify-murex.vercel.app/downloads/quicklify-latest.apk',
  updateMessage:
    'A new version of Quicklify is required. Please download the latest APK to continue.',
};

export default async function AppControlPage() {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');

  const current = await loadConfig();

  return (
    <div>
      <h1 className="text-xl font-semibold mb-1">App control</h1>
      <p className="text-muted text-sm mb-6">
        Force-update gate. To block an individual user, go to their profile in{' '}
        <a href="/users" className="text-primary hover:underline">
          Users
        </a>{' '}
        and use the Danger zone &middot; Ban action — the app will show a
        blackout screen for that user only.
      </p>
      <AppControlForm initial={current} />
    </div>
  );
}

async function loadConfig(): Promise<AppConfigRow> {
  const { db } = firebaseAdmin();
  const snap = await db.collection('config').doc('app').get();
  if (!snap.exists) return DEFAULTS;
  const d = snap.data() ?? {};
  return {
    minRequiredVersion:
      (d.minRequiredVersion as string) ?? DEFAULTS.minRequiredVersion,
    latestVersion: (d.latestVersion as string) ?? DEFAULTS.latestVersion,
    apkUrl: (d.apkUrl as string) ?? DEFAULTS.apkUrl,
    updateMessage: (d.updateMessage as string) ?? DEFAULTS.updateMessage,
  };
}
