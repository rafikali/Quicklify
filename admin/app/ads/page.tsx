import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { AdsForm, type AdsConfigRow } from './ads-form';

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
