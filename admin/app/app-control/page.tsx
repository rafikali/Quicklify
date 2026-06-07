import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { AppControlForm, type AppConfigRow } from './app-control-form';
import { HowToNote } from '@/components/how-to-note';

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

      <HowToNote
        whatToDo={[
          'Set "Latest version" to the version of the APK you just published (e.g. 1.2.3). This is what the app uses for the "update available" banner.',
          'Set "Min required version" only when you want to FORCE everyone below that version to update before they can use the app. Leave at 0.0.0 to make updates optional.',
          'Make sure "APK URL" points to the latest APK on the website (https://…/downloads/quicklify-latest.apk).',
          'Edit "Update message" — this is the text shown on the force-update screen.',
          'Click Save. The change is live in Firestore immediately.',
        ]}
        howToVerify={[
          'On the phone, install an OLDER build of the app (any build whose version is below "Min required version").',
          'Force-stop and reopen the app — the force-update screen should appear within ~2 seconds.',
          'Tap "Update now" — it should open the APK URL in the browser.',
          'Install the new APK and reopen — the app should let you in normally.',
          'For optional updates (only "Latest version" bumped), confirm an in-app "Update available" banner appears on the home screen but does not block usage.',
        ]}
        tip="Changes propagate live via Firestore — no app rebuild needed for the gate to flip. But the actual APK at the URL must be the one matching the new version number, otherwise the loop never ends."
      />

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
