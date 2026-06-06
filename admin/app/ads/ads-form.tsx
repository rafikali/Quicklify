'use client';

import { useState, useTransition } from 'react';
import { updateAdsConfigAction, type AdsConfigInput } from '../actions';

export interface AdsConfigRow extends AdsConfigInput {}

export function AdsForm({ initial }: { initial: AdsConfigRow }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState<AdsConfigRow>(initial);

  function update<K extends keyof AdsConfigRow>(key: K, value: AdsConfigRow[K]) {
    setForm((f) => ({ ...f, [key]: value }));
    setSaved(false);
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setSaved(false);
        start(async () => {
          try {
            await updateAdsConfigAction(form);
            setSaved(true);
          } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="space-y-6"
    >
      {/* ── Cadence ───────────────────────────────────────────── */}
      <section className="bg-card border border-border rounded-xl p-5 space-y-4">
        <div>
          <h2 className="font-semibold mb-1">Cadence</h2>
          <p className="text-muted text-xs">
            Interstitial frequency knobs. <span className="font-mono">0</span>{' '}
            disables a slot. <span className="font-mono">1</span> = fires on
            every download. The min-interval floor prevents back-to-back
            ads even when both slots would otherwise fire — keeps you under
            AdMob policy.
          </p>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <Field label="Interstitial on download start (every Nth)">
            <NumberInput
              value={form.interstitialOnDownloadStart}
              min={0}
              onChange={(v) => update('interstitialOnDownloadStart', v)}
            />
          </Field>
          <Field label="Interstitial on download complete (every Nth)">
            <NumberInput
              value={form.interstitialOnDownloadComplete}
              min={0}
              onChange={(v) => update('interstitialOnDownloadComplete', v)}
            />
          </Field>
        </div>

        <Field label="Min seconds between interstitials (safety floor)">
          <NumberInput
            value={form.interstitialMinIntervalSeconds}
            min={0}
            onChange={(v) => update('interstitialMinIntervalSeconds', v)}
          />
        </Field>

        <Field label="Banner ad master switch">
          <BoolToggle
            value={form.bannerEnabled}
            onChange={(v) => update('bannerEnabled', v)}
          />
        </Field>
      </section>

      {/* ── Interstitial provider ─────────────────────────────── */}
      <section className="bg-card border border-border rounded-xl p-5 space-y-4">
        <div>
          <h2 className="font-semibold mb-1">Interstitial provider</h2>
          <p className="text-muted text-xs">
            Pick where the interstitial content comes from. AdMob uses your
            live ad unit; House plays the video you point to below — useful
            for promos (premium upsell, sister app, etc.) without paying
            ad-network rev share.
          </p>
        </div>

        <ProviderToggle
          value={form.interstitialProvider}
          onChange={(v) => update('interstitialProvider', v)}
        />

        {form.interstitialProvider === 'house' && (
          <div className="space-y-3 border-l-2 border-primary/30 pl-4">
            <Field label="House interstitial video URL (https, MP4)">
              <input
                value={form.houseInterstitialVideoUrl}
                onChange={(e) =>
                  update('houseInterstitialVideoUrl', e.target.value)
                }
                placeholder="https://your-cdn.example.com/promo.mp4"
                className={`${inputCls} font-mono text-xs`}
              />
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="CTA button text (optional)">
                <input
                  value={form.houseInterstitialCtaText}
                  onChange={(e) =>
                    update('houseInterstitialCtaText', e.target.value)
                  }
                  placeholder="Get Premium"
                  className={inputCls}
                />
              </Field>
              <Field label="Skip button appears after (seconds)">
                <NumberInput
                  value={form.houseInterstitialSkipAfterSeconds}
                  min={0}
                  onChange={(v) =>
                    update('houseInterstitialSkipAfterSeconds', v)
                  }
                />
              </Field>
            </div>
            <Field label="CTA URL (https, optional)">
              <input
                value={form.houseInterstitialCtaUrl}
                onChange={(e) =>
                  update('houseInterstitialCtaUrl', e.target.value)
                }
                placeholder="https://quicklify.com/premium"
                className={`${inputCls} font-mono text-xs`}
              />
            </Field>
          </div>
        )}
      </section>

      {/* ── Banner provider ───────────────────────────────────── */}
      <section className="bg-card border border-border rounded-xl p-5 space-y-4">
        <div>
          <h2 className="font-semibold mb-1">Banner provider</h2>
          <p className="text-muted text-xs">
            Same toggle for the bottom banner. House mode shows a static
            image; tapping it opens the CTA URL.
          </p>
        </div>

        <ProviderToggle
          value={form.bannerProvider}
          onChange={(v) => update('bannerProvider', v)}
        />

        {form.bannerProvider === 'house' && (
          <div className="space-y-3 border-l-2 border-primary/30 pl-4">
            <Field label="House banner image URL (https)">
              <input
                value={form.houseBannerImageUrl}
                onChange={(e) =>
                  update('houseBannerImageUrl', e.target.value)
                }
                placeholder="https://your-cdn.example.com/banner.png"
                className={`${inputCls} font-mono text-xs`}
              />
            </Field>
            <Field label="Banner tap URL (https, optional)">
              <input
                value={form.houseBannerCtaUrl}
                onChange={(e) => update('houseBannerCtaUrl', e.target.value)}
                placeholder="https://quicklify.com/premium"
                className={`${inputCls} font-mono text-xs`}
              />
            </Field>
          </div>
        )}
      </section>

      {error && (
        <p className="text-danger text-sm bg-danger/10 border border-danger/30 rounded px-3 py-2">
          {error}
        </p>
      )}
      {saved && !error && (
        <p className="text-green-400 text-sm bg-green-400/10 border border-green-400/30 rounded px-3 py-2">
          Saved. Live users get the update on the next snapshot (seconds);
          cold-start users on their next launch.
        </p>
      )}

      <div className="flex gap-3 sticky bottom-0 bg-bg/90 backdrop-blur py-3">
        <button
          type="submit"
          disabled={pending}
          className="bg-primary text-white px-5 py-2 rounded font-medium disabled:opacity-50"
        >
          {pending ? 'Saving…' : 'Save changes'}
        </button>
      </div>
    </form>
  );
}

function ProviderToggle({
  value,
  onChange,
}: {
  value: 'admob' | 'house';
  onChange: (v: 'admob' | 'house') => void;
}) {
  return (
    <div className="inline-flex border border-border rounded overflow-hidden">
      <button
        type="button"
        onClick={() => onChange('admob')}
        className={`px-4 py-2 text-sm ${
          value === 'admob'
            ? 'bg-primary text-white'
            : 'bg-surface text-muted hover:text-text'
        }`}
      >
        AdMob
      </button>
      <button
        type="button"
        onClick={() => onChange('house')}
        className={`px-4 py-2 text-sm ${
          value === 'house'
            ? 'bg-primary text-white'
            : 'bg-surface text-muted hover:text-text'
        }`}
      >
        House ad
      </button>
    </div>
  );
}

function BoolToggle({
  value,
  onChange,
}: {
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <div className="inline-flex border border-border rounded overflow-hidden">
      <button
        type="button"
        onClick={() => onChange(true)}
        className={`px-4 py-2 text-sm ${
          value
            ? 'bg-primary text-white'
            : 'bg-surface text-muted hover:text-text'
        }`}
      >
        Enabled
      </button>
      <button
        type="button"
        onClick={() => onChange(false)}
        className={`px-4 py-2 text-sm ${
          !value
            ? 'bg-primary text-white'
            : 'bg-surface text-muted hover:text-text'
        }`}
      >
        Disabled
      </button>
    </div>
  );
}

function NumberInput({
  value,
  min,
  onChange,
}: {
  value: number;
  min?: number;
  onChange: (v: number) => void;
}) {
  return (
    <input
      type="number"
      value={value}
      min={min}
      onChange={(e) => {
        const v = parseInt(e.target.value, 10);
        onChange(Number.isNaN(v) ? (min ?? 0) : v);
      }}
      className={`${inputCls} font-mono`}
    />
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="text-xs space-y-1 block">
      <div className="text-muted">{label}</div>
      {children}
    </label>
  );
}

const inputCls =
  'w-full bg-surface border border-border rounded px-3 py-2 text-sm focus:outline-none focus:border-primary';
