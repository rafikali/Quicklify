'use client';

import { useState, useTransition } from 'react';
import { updateAppConfigAction, type AppConfigInput } from '../actions';

export interface AppConfigRow extends AppConfigInput {}

export function AppControlForm({ initial }: { initial: AppConfigRow }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState<AppConfigRow>(initial);

  function update<K extends keyof AppConfigRow>(key: K, value: AppConfigRow[K]) {
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
            await updateAppConfigAction(form);
            setSaved(true);
          } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="space-y-6"
    >
      {/* Blackout kill-switch */}
      <section className="bg-card border border-border rounded-xl p-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="font-semibold mb-1">Blackout kill-switch</h2>
            <p className="text-muted text-xs">
              When ON, every signed-in user sees a full-screen message and
              cannot use the app. Use sparingly — for security incidents,
              maintenance, or banned-region rollout. Takes effect on next
              foreground resume.
            </p>
          </div>
          <label className="inline-flex items-center cursor-pointer shrink-0">
            <input
              type="checkbox"
              className="sr-only peer"
              checked={form.blackoutEnabled}
              onChange={(e) => update('blackoutEnabled', e.target.checked)}
            />
            <div className="relative w-12 h-6 bg-surface rounded-full peer-checked:bg-danger transition-colors">
              <div
                className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full transition-transform ${
                  form.blackoutEnabled ? 'translate-x-6' : ''
                }`}
              />
            </div>
          </label>
        </div>

        <div className="mt-4">
          <Field label="Blackout message (shown to user)">
            <textarea
              value={form.blackoutMessage}
              onChange={(e) => update('blackoutMessage', e.target.value)}
              rows={2}
              className={inputCls}
            />
          </Field>
        </div>
      </section>

      {/* Force update */}
      <section className="bg-card border border-border rounded-xl p-5 space-y-4">
        <div>
          <h2 className="font-semibold mb-1">Force update</h2>
          <p className="text-muted text-xs">
            Users on versions <span className="font-mono">below</span>{' '}
            <span className="font-mono">minRequiredVersion</span> see a
            blocking screen with a Download button pointing at{' '}
            <span className="font-mono">apkUrl</span>.
          </p>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <Field label="Min required version (block below)">
            <input
              value={form.minRequiredVersion}
              onChange={(e) => update('minRequiredVersion', e.target.value)}
              placeholder="1.0.0"
              className={`${inputCls} font-mono`}
            />
          </Field>
          <Field label="Latest version (informational)">
            <input
              value={form.latestVersion}
              onChange={(e) => update('latestVersion', e.target.value)}
              placeholder="1.0.0"
              className={`${inputCls} font-mono`}
            />
          </Field>
        </div>

        <Field label="APK download URL (https)">
          <input
            value={form.apkUrl}
            onChange={(e) => update('apkUrl', e.target.value)}
            placeholder="https://..."
            className={`${inputCls} font-mono text-xs`}
          />
        </Field>

        <Field label="Update message (shown on force-update screen)">
          <textarea
            value={form.updateMessage}
            onChange={(e) => update('updateMessage', e.target.value)}
            rows={2}
            className={inputCls}
          />
        </Field>
      </section>

      {error && (
        <p className="text-danger text-sm bg-danger/10 border border-danger/30 rounded px-3 py-2">
          {error}
        </p>
      )}
      {saved && !error && (
        <p className="text-green-400 text-sm bg-green-400/10 border border-green-400/30 rounded px-3 py-2">
          Saved. Users will see changes on next launch or resume.
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
