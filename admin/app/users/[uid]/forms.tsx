'use client';

import { useState, useTransition } from 'react';
import {
  banUserAction,
  grantPremiumAction,
  revokeDeviceAction,
  revokePremiumAction,
} from '../../actions';

export function GrantPremiumForm({ targetUid }: { targetUid: string }) {
  const [pending, start] = useTransition();
  const [duration, setDuration] = useState<number | null>(365);
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        start(async () => {
          try {
            await grantPremiumAction(targetUid, duration, note);
          } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="space-y-3"
    >
      <div className="flex gap-2">
        {[30, 90, 365, null].map((d) => (
          <button
            type="button"
            key={String(d)}
            onClick={() => setDuration(d)}
            className={`px-3 py-1.5 rounded text-sm border ${
              duration === d
                ? 'bg-primary border-primary text-white'
                : 'border-border text-muted hover:text-text'
            }`}
          >
            {d === null ? 'Lifetime' : `${d} days`}
          </button>
        ))}
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

export function BanUserForm({ targetUid, banned }: { targetUid: string; banned: boolean }) {
  const [pending, start] = useTransition();
  const [reason, setReason] = useState('');

  if (banned) {
    return <p className="text-danger text-sm">This user is currently banned.</p>;
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (reason.trim().length < 3) {
          alert('Reason required (min 3 chars)');
          return;
        }
        if (!confirm('Permanently ban this user? Revokes all subscriptions and devices.')) return;
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
        placeholder="Ban reason (required)"
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
