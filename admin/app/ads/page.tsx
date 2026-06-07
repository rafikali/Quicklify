import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { AdsForm, type AdsConfigRow } from './ads-form';
import { HowToNote } from '@/components/how-to-note';

export const dynamic = 'force-dynamic';

const DEFAULTS: AdsConfigRow = {
  interstitialOnDownloadStart: 1,
  interstitialOnDownloadComplete: 1,
  interstitialMinIntervalSeconds: 30,
  bannerEnabled: true,
  interstitialProvider: 'admob',
  bannerProvider: 'admob',
  houseInterstitialVideoUrl: '',
  houseInterstitialCtaText: '',
  houseInterstitialCtaUrl: '',
  houseInterstitialSkipAfterSeconds: 5,
  houseBannerImageUrl: '',
  houseBannerCtaUrl: '',
};

export default async function AdsPage() {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');

  const current = await loadConfig();

  return (
    <div>
      <h1 className="text-xl font-semibold mb-1">Ads control</h1>
      <p className="text-muted text-sm mb-6">
        Tune ad cadence and switch between AdMob and in-app &ldquo;house&rdquo;
        ads (your own promo video / banner). Changes take effect on every
        user&apos;s next app launch or on the next Firestore snapshot —
        usually within seconds for users actively in the app.
      </p>

      <HowToNote
        whatToDo={[
          'Cadence: "Show every N downloads" controls how often a full-screen ad appears. 1 = every download (most aggressive — pushes premium). Higher = lighter.',
          'Min interval: minimum seconds between two interstitials so two ads do not stack.',
          'Interstitial provider: pick "admob" for real AdMob ads, or "house" to play YOUR OWN promo video (set the URL + CTA below).',
          'Banner provider: same choice for the small banner ad on screen edges.',
          'If you switch to "house", fill the Video URL (mp4), CTA text, CTA URL, and skip-after seconds. For banner: image URL + tap-through URL.',
          'Click Save. The mobile app picks up the new config within ~2 seconds via Firestore stream.',
        ]}
        howToVerify={[
          'Open the app and download any video.',
          'On the download-complete screen, the ad should appear with the cadence and provider you configured.',
          'To verify the provider switch: set provider=house, save, then trigger a download → you should see your promo video (not AdMob test ad).',
          'To verify cadence: set "every 1 download", do two downloads back-to-back → both should show ads (subject to the min-interval guard).',
          'To verify the min-interval guard: set min-interval=60, do two downloads within 30s → second one should NOT show an ad.',
        ]}
        tip="No app rebuild needed for cadence/provider changes — they hot-reload from Firestore. But the first launch after install must succeed before changes can stream in."
      />

      <AdsForm initial={current} />
    </div>
  );
}

async function loadConfig(): Promise<AdsConfigRow> {
  const { db } = firebaseAdmin();
  const snap = await db.collection('config').doc('ads').get();
  if (!snap.exists) return DEFAULTS;
  const d = snap.data() ?? {};
  return {
    interstitialOnDownloadStart:
      (d.interstitialOnDownloadStart as number) ?? DEFAULTS.interstitialOnDownloadStart,
    interstitialOnDownloadComplete:
      (d.interstitialOnDownloadComplete as number) ?? DEFAULTS.interstitialOnDownloadComplete,
    interstitialMinIntervalSeconds:
      (d.interstitialMinIntervalSeconds as number) ?? DEFAULTS.interstitialMinIntervalSeconds,
    bannerEnabled: (d.bannerEnabled as boolean) ?? DEFAULTS.bannerEnabled,
    interstitialProvider:
      (d.interstitialProvider as 'admob' | 'house') ?? DEFAULTS.interstitialProvider,
    bannerProvider:
      (d.bannerProvider as 'admob' | 'house') ?? DEFAULTS.bannerProvider,
    houseInterstitialVideoUrl:
      (d.houseInterstitialVideoUrl as string) ?? '',
    houseInterstitialCtaText:
      (d.houseInterstitialCtaText as string) ?? '',
    houseInterstitialCtaUrl:
      (d.houseInterstitialCtaUrl as string) ?? '',
    houseInterstitialSkipAfterSeconds:
      (d.houseInterstitialSkipAfterSeconds as number) ??
      DEFAULTS.houseInterstitialSkipAfterSeconds,
    houseBannerImageUrl: (d.houseBannerImageUrl as string) ?? '',
    houseBannerCtaUrl: (d.houseBannerCtaUrl as string) ?? '',
  };
}
