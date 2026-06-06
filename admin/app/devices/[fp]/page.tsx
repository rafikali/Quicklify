import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

interface DeviceDetail {
  fp: string;
  label: string | null;
  platform: string | null;
  lastVersion: string | null;
  lastSeenAt: number | null;
  firstSeenAt: number | null;
  lastUserUid: string | null;
  banned: boolean;
  banReason: string | null;
  activity: Array<{
    id: string;
    name: string;
    timestamp: number | null;
    sessionId: string | null;
    appVersion: string | null;
    params: Record<string, unknown>;
  }>;
}

export default async function DeviceDetailPage({
  params,
}: {
  params: Promise<{ fp: string }>;
}) {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');
  const { fp } = await params;
  const device = await loadDevice(fp);
  if (!device) notFound();

  return (
    <div>
      <Link href="/devices" className="text-muted text-sm hover:text-text">
        ← Back to devices
      </Link>

      <div className="mt-4">
        <h1 className="text-xl font-semibold">
          {device.label ?? 'Unknown device'}
        </h1>
        <p className="text-muted text-xs font-mono mt-1 break-all">
          {device.fp}
        </p>
      </div>

      <Section title="Device metadata">
        <dl className="grid grid-cols-2 gap-y-2 text-sm">
          <Row k="Platform" v={device.platform ?? '—'} mono />
          <Row k="Last app version" v={device.lastVersion ?? '—'} mono />
          <Row
            k="First seen"
            v={
              device.firstSeenAt
                ? new Date(device.firstSeenAt).toLocaleString()
                : '—'
            }
          />
          <Row
            k="Last seen"
            v={
              device.lastSeenAt
                ? new Date(device.lastSeenAt).toLocaleString()
                : '—'
            }
          />
          <Row
            k="Last signed-in user"
            v={
              device.lastUserUid ? (
                <Link
                  href={`/users/${device.lastUserUid}`}
                  className="text-primary hover:underline font-mono"
                >
                  {device.lastUserUid.slice(0, 12)}…
                </Link>
              ) : (
                <span className="text-muted">signed out</span>
              )
            }
          />
          <Row
            k="Status"
            v={
              device.banned ? (
                <span className="text-danger font-medium">
                  BANNED{device.banReason && ` — “${device.banReason}”`}
                </span>
              ) : (
                <span className="text-muted">active</span>
              )
            }
          />
        </dl>
      </Section>

      <Section title="Anonymous activity (last 100)">
        <p className="text-muted text-xs mb-3">
          Events written by this device while signed out. Once a user signs in
          on this device the matching events are mirrored into their profile
          log under{' '}
          <code className="font-mono">profiles/{'{uid}'}/activity</code>.
        </p>
        {device.activity.length === 0 ? (
          <p className="text-muted text-sm">No anonymous activity yet.</p>
        ) : (
          <ul className="space-y-1.5 text-sm">
            {device.activity.map((ev) => (
              <li
                key={ev.id}
                className="bg-surface border border-border rounded p-2.5"
              >
                <div className="flex items-center justify-between">
                  <code className="text-primary text-xs">{ev.name}</code>
                  <span className="text-muted text-xs">
                    {ev.timestamp
                      ? new Date(ev.timestamp).toLocaleString()
                      : '—'}
                  </span>
                </div>
                {Object.keys(ev.params).length > 0 && (
                  <div className="flex flex-wrap gap-2 mt-1.5">
                    {Object.entries(ev.params)
                      .filter(([k]) => k !== 'session_id')
                      .map(([k, v]) => (
                        <span
                          key={k}
                          className="text-xs text-muted bg-bg/70 px-1.5 py-0.5 rounded"
                        >
                          {k}=<span className="text-text">{String(v)}</span>
                        </span>
                      ))}
                  </div>
                )}
                {ev.sessionId && (
                  <div className="text-muted text-[10px] mt-1 font-mono">
                    session {ev.sessionId.slice(0, 8)}…
                    {ev.appVersion && ` · v${ev.appVersion}`}
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </Section>
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-8">
      <h2 className="text-sm uppercase tracking-wider text-muted mb-3">
        {title}
      </h2>
      <div className="bg-card border border-border rounded-xl p-4">
        {children}
      </div>
    </section>
  );
}

function Row({
  k,
  v,
  mono = false,
}: {
  k: string;
  v: React.ReactNode;
  mono?: boolean;
}) {
  return (
    <>
      <dt className="text-muted">{k}</dt>
      <dd className={mono ? 'font-mono' : ''}>{v}</dd>
    </>
  );
}

async function loadDevice(fp: string): Promise<DeviceDetail | null> {
  const { db } = firebaseAdmin();
  const [deviceSnap, activitySnap] = await Promise.all([
    db.collection('device_registry').doc(fp).get(),
    db
      .collection('anonymous_activity')
      .doc(fp)
      .collection('events')
      .orderBy('timestamp', 'desc')
      .limit(100)
      .get(),
  ]);

  if (!deviceSnap.exists) return null;
  const d = deviceSnap.data()!;

  const activity = activitySnap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: (data.name as string) ?? '',
      timestamp: data.timestamp?.toMillis?.() ?? null,
      sessionId: (data.sessionId as string | undefined) ?? null,
      appVersion: (data.appVersion as string | undefined) ?? null,
      params: (data.params ?? {}) as Record<string, unknown>,
    };
  });

  return {
    fp,
    label: (d.deviceLabel as string) ?? null,
    platform: (d.platform as string) ?? null,
    lastVersion: (d.lastVersion as string) ?? null,
    lastSeenAt: d.lastSeenAt?.toMillis?.() ?? null,
    firstSeenAt: d.firstSeenAt?.toMillis?.() ?? null,
    lastUserUid: (d.lastUserUid as string | null) ?? null,
    banned: (d.banned as boolean) ?? false,
    banReason: (d.banReason as string | null) ?? null,
    activity,
  };
}
