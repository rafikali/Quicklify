'use client';

import Link from 'next/link';
import { useState, useTransition } from 'react';
import { banDeviceAction, unbanDeviceAction } from '../actions';

export interface DeviceRow {
  id: string;
  label: string | null;
  platform: string | null;
  lastVersion: string | null;
  lastSeenAt: number | null;
  firstSeenAt: number | null;
  lastUserUid: string | null;
  banned: boolean;
  banReason: string | null;
  bannedAt: number | null;
}

type Tab = 'recent' | 'banned' | 'manual';

export function DevicesManager({
  recent,
  banned,
}: {
  recent: DeviceRow[];
  banned: DeviceRow[];
}) {
  const [tab, setTab] = useState<Tab>('recent');

  return (
    <div className="space-y-4">
      <div className="flex gap-1 border-b border-border">
        <TabBtn current={tab} value="recent" onClick={setTab}>
          Recent ({recent.length})
        </TabBtn>
        <TabBtn current={tab} value="banned" onClick={setTab}>
          Banned ({banned.length})
        </TabBtn>
        <TabBtn current={tab} value="manual" onClick={setTab}>
          Ban by ID
        </TabBtn>
      </div>

      {tab === 'recent' && <DeviceTable rows={recent} emptyHint="No devices have heart-beat yet." />}
      {tab === 'banned' && <DeviceTable rows={banned} emptyHint="No banned devices." />}
      {tab === 'manual' && <ManualBanForm />}
    </div>
  );
}

function TabBtn({
  current,
  value,
  onClick,
  children,
}: {
  current: Tab;
  value: Tab;
  onClick: (t: Tab) => void;
  children: React.ReactNode;
}) {
  const active = current === value;
  return (
    <button
      onClick={() => onClick(value)}
      className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
        active
          ? 'border-primary text-text'
          : 'border-transparent text-muted hover:text-text'
      }`}
    >
      {children}
    </button>
  );
}

function DeviceTable({ rows, emptyHint }: { rows: DeviceRow[]; emptyHint: string }) {
  if (rows.length === 0) {
    return (
      <div className="bg-card border border-border rounded-xl p-10 text-center text-muted text-sm">
        {emptyHint}
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-border bg-card">
      <table className="w-full text-sm">
        <thead className="bg-surface text-muted text-left">
          <tr>
            <th className="py-2.5 px-4 font-medium">Device</th>
            <th className="py-2.5 px-4 font-medium">Last seen</th>
            <th className="py-2.5 px-4 font-medium">Version</th>
            <th className="py-2.5 px-4 font-medium">User</th>
            <th className="py-2.5 px-4 font-medium">Status</th>
            <th className="py-2.5 px-4 font-medium"></th>
          </tr>
        </thead>
        <tbody>
          {rows.map((d) => (
            <DeviceRowItem key={d.id} d={d} />
          ))}
        </tbody>
      </table>
    </div>
  );
}

function DeviceRowItem({ d }: { d: DeviceRow }) {
  return (
    <tr className="border-t border-border align-top">
      <td className="py-2.5 px-4">
        <Link
          href={`/devices/${d.id}`}
          className="font-medium hover:text-primary hover:underline"
        >
          {d.label ?? 'Unknown device'}
        </Link>
        <div className="text-xs text-muted font-mono mt-0.5">
          {d.id.slice(0, 12)}…{d.id.slice(-6)}
        </div>
      </td>
      <td className="py-2.5 px-4 text-xs">
        {d.lastSeenAt ? new Date(d.lastSeenAt).toLocaleString() : '—'}
      </td>
      <td className="py-2.5 px-4 font-mono text-xs">{d.lastVersion ?? '—'}</td>
      <td className="py-2.5 px-4 text-xs">
        {d.lastUserUid ? (
          <Link
            href={`/users/${d.lastUserUid}`}
            className="text-primary hover:underline font-mono"
          >
            {d.lastUserUid.slice(0, 8)}…
          </Link>
        ) : (
          <span className="text-muted">signed out</span>
        )}
      </td>
      <td className="py-2.5 px-4">
        {d.banned ? (
          <div>
            <span className="text-danger font-medium">BANNED</span>
            {d.banReason && (
              <div className="text-xs text-muted mt-0.5">&ldquo;{d.banReason}&rdquo;</div>
            )}
          </div>
        ) : (
          <span className="text-muted text-xs">active</span>
        )}
      </td>
      <td className="py-2.5 px-4 text-right">
        <RowActions d={d} />
      </td>
    </tr>
  );
}

function RowActions({ d }: { d: DeviceRow }) {
  const [pending, start] = useTransition();
  const [reason, setReason] = useState('');
  const [opening, setOpening] = useState(false);

  if (d.banned) {
    return (
      <button
        disabled={pending}
        onClick={() => {
          if (!confirm('Unban this device?')) return;
          start(async () => {
            try {
              await unbanDeviceAction(d.id);
            } catch (err) {
              alert(err instanceof Error ? err.message : String(err));
            }
          });
        }}
        className="text-primary hover:underline text-xs disabled:opacity-50"
      >
        {pending ? '…' : 'Unban'}
      </button>
    );
  }

  if (!opening) {
    return (
      <button
        onClick={() => setOpening(true)}
        className="text-danger hover:underline text-xs"
      >
        Ban
      </button>
    );
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (reason.trim().length < 3) {
          alert('Reason required');
          return;
        }
        if (!confirm(`Ban this device?\n\n${d.label ?? d.id.slice(0, 12)}`)) return;
        start(async () => {
          try {
            await banDeviceAction(d.id, reason);
            setOpening(false);
            setReason('');
          } catch (err) {
            alert(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="flex gap-2 justify-end"
    >
      <input
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        placeholder="Reason"
        className="bg-surface border border-border rounded px-2 py-1 text-xs w-32"
        autoFocus
      />
      <button
        type="submit"
        disabled={pending}
        className="bg-danger text-white px-2 py-1 rounded text-xs font-medium disabled:opacity-50"
      >
        {pending ? '…' : 'Ban'}
      </button>
      <button
        type="button"
        onClick={() => {
          setOpening(false);
          setReason('');
        }}
        className="text-muted text-xs"
      >
        Cancel
      </button>
    </form>
  );
}

function ManualBanForm() {
  const [pending, start] = useTransition();
  const [deviceId, setDeviceId] = useState('');
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setSuccess(null);
        start(async () => {
          try {
            await banDeviceAction(deviceId, reason);
            setSuccess(`Banned device ${deviceId.slice(0, 12)}…`);
            setDeviceId('');
            setReason('');
          } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="bg-card border border-border rounded-xl p-5 space-y-3 max-w-2xl"
    >
      <div>
        <h2 className="font-semibold mb-1">Ban by device ID</h2>
        <p className="text-muted text-xs">
          Use this when you already know the device fingerprint (e.g. from
          user support or audit log). The doc will be created if it
          doesn&apos;t exist yet — when that device next opens the app, the
          blackout fires immediately.
        </p>
      </div>
      <div>
        <label className="text-xs text-muted block mb-1">
          Device ID (sha256, 64 hex chars)
        </label>
        <input
          value={deviceId}
          onChange={(e) => setDeviceId(e.target.value)}
          placeholder="abcd1234…"
          className="w-full bg-surface border border-border rounded px-3 py-2 text-sm font-mono"
        />
      </div>
      <div>
        <label className="text-xs text-muted block mb-1">
          Reason (shown to user on the blackout screen)
        </label>
        <input
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Abuse / chargeback / etc."
          className="w-full bg-surface border border-border rounded px-3 py-2 text-sm"
        />
      </div>
      {error && (
        <p className="text-danger text-sm bg-danger/10 border border-danger/30 rounded px-3 py-2">
          {error}
        </p>
      )}
      {success && (
        <p className="text-green-400 text-sm bg-green-400/10 border border-green-400/30 rounded px-3 py-2">
          {success}
        </p>
      )}
      <button
        type="submit"
        disabled={pending}
        className="bg-danger text-white px-4 py-2 rounded font-medium disabled:opacity-50"
      >
        {pending ? 'Banning…' : 'Ban device'}
      </button>
    </form>
  );
}
