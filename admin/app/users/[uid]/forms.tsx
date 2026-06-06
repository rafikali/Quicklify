'use client';

import { useState, useTransition } from 'react';
import {
  banUserAction,
  grantPremiumAction,
  revokeDeviceAction,
  revokePremiumAction,
  unbanUserAction,
} from '../../actions';

export interface GrantPlanOption {
  id: string;
  name: string;
  durationDays: number;
  priceInr: number;
  currency: string;
  sortOrder: number;
}

interface GrantSelection {
  planId: string | null; // null = manual override (lifetime / custom)
  durationDays: number | null;
  priceInr: number | null;
}

export function GrantPremiumForm({
  targetUid,
  plans,
}: {
  targetUid: string;
  plans: GrantPlanOption[];
}) {
  const [pending, start] = useTransition();
  const [selection, setSelection] = useState<GrantSelection>(() => {
    if (plans.length > 0) {
      const p = plans[Math.floor(plans.length / 2)];
      return { planId: p.id, durationDays: p.durationDays, priceInr: p.priceInr };
    }
    return { planId: null, durationDays: 365, priceInr: null };
  });
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        start(async () => {
          try {
            await grantPremiumAction(
              targetUid,
              selection.durationDays,
              note,
              selection.planId,
              selection.priceInr
            );
          } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="space-y-3"
    >
      {plans.length === 0 ? (
        <div className="bg-surface border border-border rounded p-3 text-sm text-muted">
          No plans defined yet. Add some in{' '}
          <a href="/plans" className="text-primary hover:underline">
            Plans
          </a>
          , or use the manual durations below.
        </div>
      ) : (
        <div className="flex flex-wrap gap-2">
          {plans.map((p) => {
            const active = selection.planId === p.id;
            return (
              <button
                type="button"
                key={p.id}
                onClick={() =>
                  setSelection({
                    planId: p.id,
                    durationDays: p.durationDays,
                    priceInr: p.priceInr,
                  })
                }
                className={`px-3 py-1.5 rounded text-sm border ${
                  active
                    ? 'bg-primary border-primary text-white'
                    : 'border-border text-muted hover:text-text'
                }`}
              >
                {p.name} · {p.currency} {p.priceInr} · {p.durationDays}d
              </button>
            );
          })}
        </div>
      )}

      <div className="flex flex-wrap gap-2 items-center">
        <span className="text-xs text-muted uppercase tracking-wide">
          Or manual:
        </span>
        {[30, 90, 365, null].map((d) => {
          const active =
            selection.planId === null && selection.durationDays === d;
          return (
            <button
              type="button"
              key={String(d)}
              onClick={() =>
                setSelection({
                  planId: null,
                  durationDays: d,
                  priceInr: null,
                })
              }
              className={`px-3 py-1.5 rounded text-sm border ${
                active
                  ? 'bg-primary border-primary text-white'
                  : 'border-border text-muted hover:text-text'
              }`}
            >
              {d === null ? 'Lifetime' : `${d} days`}
            </button>
          );
        })}
      </div>

      <input
        value={note}
        onChange={(e) => setNote(e.target.value)}
        placeholder="Optional note for audit log"
        className="w-full bg-surface border border-border rounded px-3 py-2 text-sm"
      />
      <button
        type="submit"
        disabled={pending}
        className="bg-primary text-white px-4 py-2 rounded font-medium disabled:opacity-50"
      >
        {pending ? 'Granting…' : 'Grant premium'}
      </button>
      {error && <p className="text-danger text-sm">{error}</p>}
    </form>
  );
}

export function RevokePremiumForm({ targetUid }: { targetUid: string }) {
  const [pending, start] = useTransition();
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (reason.trim().length < 3) {
          setError('Reason required (min 3 chars)');
          return;
        }
        if (!confirm('Revoke active premium subscription?')) return;
        setError(null);
        start(async () => {
          try {
            await revokePremiumAction(targetUid, reason);
            setReason('');
          } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="flex gap-2 items-start"
    >
      <input
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        placeholder="Reason (required)"
        className="flex-1 bg-surface border border-border rounded px-3 py-2 text-sm"
      />
      <button
        type="submit"
        disabled={pending}
        className="bg-danger text-white px-4 py-2 rounded font-medium disabled:opacity-50 whitespace-nowrap"
      >
        {pending ? 'Revoking…' : 'Revoke'}
      </button>
      {error && <p className="text-danger text-sm">{error}</p>}
    </form>
  );
}

export function RevokeDeviceButton({
  targetUid,
  deviceId,
}: {
  targetUid: string;
  deviceId: string;
}) {
  const [pending, start] = useTransition();

  return (
    <button
      onClick={() => {
        if (!confirm('Revoke this device?')) return;
        start(async () => {
          try {
            await revokeDeviceAction(targetUid, deviceId);
          } catch (err) {
            alert(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      disabled={pending}
      className="text-danger text-xs hover:underline disabled:opacity-50"
    >
      {pending ? 'Revoking…' : 'Revoke'}
    </button>
  );
}

export function BanUserForm({
  targetUid,
  banned,
  banReason,
}: {
  targetUid: string;
  banned: boolean;
  banReason: string | null;
}) {
  const [pending, start] = useTransition();
  const [reason, setReason] = useState('');

  if (banned) {
    return (
      <div className="space-y-3">
        <div className="bg-danger/10 border border-danger/30 rounded p-3 text-sm">
          <p className="text-danger font-medium mb-1">
            This user is currently banned.
          </p>
          {banReason && (
            <p className="text-muted text-xs">
              Reason shown to user:{' '}
              <span className="text-text">&ldquo;{banReason}&rdquo;</span>
            </p>
          )}
          <p className="text-muted text-xs mt-1">
            The app shows a full-screen blackout to this user. Unbanning does
            not auto-restore premium or devices.
          </p>
        </div>
        <button
          disabled={pending}
          onClick={() => {
            if (!confirm('Unban this user?')) return;
            start(async () => {
              try {
                await unbanUserAction(targetUid);
              } catch (err) {
                alert(err instanceof Error ? err.message : String(err));
              }
            });
          }}
          className="bg-surface border border-border text-text px-4 py-2 rounded font-medium disabled:opacity-50 hover:border-primary"
        >
          {pending ? 'Unbanning…' : 'Unban user'}
        </button>
      </div>
    );
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (reason.trim().length < 3) {
          alert('Reason required (min 3 chars)');
          return;
        }
        if (
          !confirm(
            'Ban this user? Revokes all active subscriptions and shows a full-screen blackout in the app. (Reversible.)'
          )
        )
          return;
        start(async () => {
          try {
            await banUserAction(targetUid, reason);
          } catch (err) {
            alert(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="flex gap-2"
    >
      <input
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        placeholder="Ban reason (shown to user)"
        className="flex-1 bg-surface border border-border rounded px-3 py-2 text-sm"
      />
      <button
        type="submit"
        disabled={pending}
        className="bg-danger text-white px-4 py-2 rounded font-medium disabled:opacity-50"
      >
        {pending ? 'Banning…' : 'Ban user'}
      </button>
    </form>
  );
}
