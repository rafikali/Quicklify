import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { AppControlForm, type AppConfigRow } from './app-control-form';

export const dynamic = 'force-dynamic';

const DEFAULTS: AppConfigRow = {
  minRequiredVersion: '0.0.0',
  latestVersion: '0.0.0',
  apkUrl: 'https://quicklify-murex.vercel.app/downloads/quicklify-latest.apk',
  blackoutEnabled: false,
  blackoutMessage: 'Quicklify is temporarily unavailable.',
  updateMessage:
    'A new version of Quicklify is required. Please download the latest APK to continue.',
};

export default async function AppControlPage() {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');

  const current = await loadConfig();

  return (
    <div>
      <div className="flex items-baseline justify-between mb-1">
        <h1 className="text-xl font-semibold">App control</h1>
        {current.blackoutEnabled && (
          <span className="text-xs px-2 py-0.5 rounded bg-danger/15 text-danger font-medium">
            BLACKOUT LIVE
          </span>
        )}
      </div>
      <p className="text-muted text-sm mb-6">
        Force-update gate + blackout kill-switch. Changes take effect on every
        user&apos;s next app launch or foreground resume — no rebuild needed.
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
    blackoutEnabled: (d.blackoutEnabled as boolean) ?? false,
    blackoutMessage:
      (d.blackoutMessage as string) ?? DEFAULTS.blackoutMessage,
    updateMessage: (d.updateMessage as string) ?? DEFAULTS.updateMessage,
  };
}
