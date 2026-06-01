import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { GrantPremiumForm, RevokePremiumForm, RevokeDeviceButton, BanUserForm, type GrantPlanOption } from './forms';

interface UserDetail {
  uid: string;
  email: string;
  displayName: string | null;
  photoUrl: string | null;
  banned: boolean;
  createdAt: number | null;
  lastSeenAt: number | null;
  activeSubscription: {
    id: string;
    startsAt: number | null;
    endsAt: number | null;
    source: string;
  } | null;
  devices: Array<{
    id: string;
    name: string;
    registeredAt: number | null;
    lastSeenAt: number | null;
  }>;
  audit: Array<{
    id: string;
    action: string;
    actorAdminUid: string | null;
    actorUserUid: string | null;
    createdAt: number | null;
    afterState: Record<string, unknown>;
  }>;
}

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ uid: string }>;
}) {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');
  const { uid } = await params;
  const [user, planOptions] = await Promise.all([
    loadUser(uid),
    loadPlanOptions(),
  ]);
  if (!user) notFound();

  return (
    <div>
      <Link href="/users" className="text-muted text-sm hover:text-text">← Back to users</Link>
      <div className="mt-4 flex items-center gap-4">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        {user.photoUrl && (
          <img
            src={user.photoUrl}
            alt=""
            className="w-12 h-12 rounded-full border border-border"
          />
        )}
        <div>
          <h1 className="text-xl font-semibold">{user.displayName ?? user.email}</h1>
          <p className="text-muted text-sm">{user.email}</p>
        </div>
        {user.banned && (
          <span className="ml-auto text-danger font-medium">BANNED</span>
        )}
      </div>

      <Section title="Subscription">
        {user.activeSubscription ? (
          <div className="space-y-1 text-sm">
            <p>
              <span className="text-muted">Source:</span>{' '}
              <code className="text-primary">{user.activeSubscription.source}</code>
            </p>
            <p>
              <span className="text-muted">Ends:</span>{' '}
              {user.activeSubscription.endsAt
                ? new Date(user.activeSubscription.endsAt).toLocaleString()
                : 'Lifetime'}
            </p>
            <div className="pt-3">
              <RevokePremiumForm targetUid={user.uid} />
            </div>
          </div>
        ) : (
          <div>
            <p className="text-muted text-sm mb-3">No active premium subscription.</p>
            <GrantPremiumForm targetUid={user.uid} plans={planOptions} />
          </div>
        )}
      </Section>

      <Section title="Devices">
        {user.devices.length === 0 ? (
          <p className="text-muted text-sm">No active devices.</p>
        ) : (
          <ul className="divide-y divide-border">
            {user.devices.map((d) => (
              <li key={d.id} className="flex items-center py-2 text-sm">
                <div className="flex-1">
                  <div>{d.name}</div>
                  <div className="text-muted text-xs">
                    Registered {d.registeredAt ? new Date(d.registeredAt).toLocaleString() : '—'}
                    {d.lastSeenAt && ` · Last seen ${new Date(d.lastSeenAt).toLocaleString()}`}
                  </div>
                </div>
                <RevokeDeviceButton targetUid={user.uid} deviceId={d.id} />
              </li>
            ))}
          </ul>
        )}
      </Section>

      <Section title="Audit log (last 50)">
        {user.audit.length === 0 ? (
          <p className="text-muted text-sm">No audit entries yet.</p>
        ) : (
          <ul className="space-y-2 text-sm">
            {user.audit.map((a) => (
              <li key={a.id} className="bg-surface border border-border rounded p-3">
                <div className="flex items-center justify-between">
                  <code className="text-primary">{a.action}</code>
                  <span className="text-muted text-xs">
                    {a.createdAt ? new Date(a.createdAt).toLocaleString() : '—'}
                  </span>
                </div>
                <div className="text-xs text-muted mt-1">
                  By {a.actorAdminUid ? `admin ${a.actorAdminUid.slice(0, 8)}…` : 'user'}
                </div>
                {Object.keys(a.afterState).length > 0 && (
                  <pre className="text-xs text-muted mt-2 overflow-x-auto">
                    {JSON.stringify(a.afterState, null, 2)}
                  </pre>
                )}
              </li>
            ))}
          </ul>
        )}
      </Section>

      <Section title="Danger zone">
        <BanUserForm targetUid={user.uid} banned={user.banned} />
      </Section>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mt-8">
      <h2 className="text-sm uppercase tracking-wider text-muted mb-3">{title}</h2>
      <div className="bg-card border border-border rounded-xl p-4">{children}</div>
    </section>
  );
}

async function loadUser(uid: string): Promise<UserDetail | null> {
  const { db } = firebaseAdmin();
  const profileSnap = await db.collection('profiles').doc(uid).get();
  if (!profileSnap.exists) return null;
  const p = profileSnap.data()!;

  const [subsSnap, devicesSnap, auditSnap] = await Promise.all([
    db
      .collection('profiles').doc(uid).collection('subscriptions')
      .where('active', '==', true).limit(1).get(),
    db
      .collection('profiles').doc(uid).collection('devices')
      .where('revokedAt', '==', null).get(),
    db
      .collection('audit_log').where('targetUserUid', '==', uid)
      .orderBy('createdAt', 'desc').limit(50).get(),
  ]);

  const activeSubscription = subsSnap.empty
    ? null
    : (() => {
        const d = subsSnap.docs[0];
        const data = d.data();
        return {
          id: d.id,
          startsAt: data.startsAt?.toMillis?.() ?? null,
          endsAt: data.endsAt?.toMillis?.() ?? null,
          source: data.source ?? '',
        };
      })();

  const devices = devicesSnap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      name: data.deviceName ?? 'Unknown',
      registeredAt: data.registeredAt?.toMillis?.() ?? null,
      lastSeenAt: data.lastSeenAt?.toMillis?.() ?? null,
    };
  });

  const audit = auditSnap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      action: data.action ?? '',
      actorAdminUid: data.actorAdminUid ?? null,
      actorUserUid: data.actorUserUid ?? null,
      createdAt: data.createdAt?.toMillis?.() ?? null,
      afterState: (data.afterState ?? {}) as Record<string, unknown>,
    };
  });

  return {
    uid,
    email: p.email ?? '',
    displayName: p.displayName ?? null,
    photoUrl: p.photoUrl ?? null,
    banned: p.banned === true,
    createdAt: p.createdAt?.toMillis?.() ?? null,
    lastSeenAt: p.lastSeenAt?.toMillis?.() ?? null,
    activeSubscription,
    devices,
    audit,
  };
}

async function loadPlanOptions(): Promise<GrantPlanOption[]> {
  const { db } = firebaseAdmin();
  const snap = await db
    .collection('plans')
    .where('active', '==', true)
    .get();
  const rows: GrantPlanOption[] = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      name: (data.name as string) ?? d.id,
      durationDays: (data.durationDays as number) ?? 0,
      priceInr: (data.priceInr as number) ?? 0,
      currency: (data.currency as string) ?? 'Rs',
      sortOrder: (data.sortOrder as number) ?? 0,
    };
  });
  rows.sort((a, b) => a.sortOrder - b.sortOrder || a.priceInr - b.priceInr);
  return rows;
}
