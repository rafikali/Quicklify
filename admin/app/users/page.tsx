import Link from 'next/link';
import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { HowToNote } from '@/components/how-to-note';

interface ProfileRow {
  uid: string;
  email: string;
  displayName: string | null;
  banned: boolean;
  lastSeenAt: number | null;
  createdAt: number | null;
  hasActivePremium: boolean;
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');

  const { q } = await searchParams;
  const rows = await loadProfiles(q);

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">Users</h1>

      <HowToNote
        whatToDo={[
          'Search by email to find a specific signed-in user.',
          'Click "Manage →" on any row to open the user profile.',
          'Inside the profile you can: grant premium for a chosen plan, revoke premium, revoke individual devices, ban the user, or review their activity log + audit log.',
        ]}
        howToVerify={[
          'On the test phone, sign in with a Google account that has email X.',
          'On this page, type X into the search box → the profile should appear within a few seconds (after the first launch heart-beats the profile doc).',
          'Click Manage → grant premium for any plan → on the phone, force-stop & reopen → premium features should now be unlocked.',
        ]}
        tip="A user only shows up here AFTER they sign in for the first time (the app creates their profile doc on first auth). Signed-out users live under the Devices tab."
      />

      <form className="mb-6" action="/users" method="GET">
        <input
          name="q"
          defaultValue={q ?? ''}
          placeholder="Search by email…"
          className="bg-card border border-border rounded-lg px-3 py-2 w-80 text-sm focus:outline-none focus:border-primary"
        />
      </form>

      <div className="bg-card border border-border rounded-xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="text-muted border-b border-border">
            <tr>
              <th className="text-left p-3">User</th>
              <th className="text-left p-3">Tier</th>
              <th className="text-left p-3">Last seen</th>
              <th className="text-left p-3">Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr>
                <td colSpan={5} className="p-6 text-center text-muted">
                  No matching users.
                </td>
              </tr>
            )}
            {rows.map((r) => (
              <tr key={r.uid} className="border-b border-border last:border-0 hover:bg-surface">
                <td className="p-3">
                  <div className="font-medium">{r.displayName ?? r.email}</div>
                  <div className="text-muted text-xs">{r.email}</div>
                </td>
                <td className="p-3">
                  {r.hasActivePremium ? (
                    <span className="text-primary font-medium">Premium</span>
                  ) : (
                    <span className="text-muted">Free</span>
                  )}
                </td>
                <td className="p-3 text-muted">
                  {r.lastSeenAt ? relative(r.lastSeenAt) : '—'}
                </td>
                <td className="p-3">
                  {r.banned ? (
                    <span className="text-danger">Banned</span>
                  ) : (
                    <span className="text-success">Active</span>
                  )}
                </td>
                <td className="p-3 text-right">
                  <Link
                    href={`/users/${r.uid}`}
                    className="text-primary hover:underline text-sm"
                  >
                    Manage →
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

async function loadProfiles(query: string | undefined): Promise<ProfileRow[]> {
  const { db } = firebaseAdmin();
  let q = db.collection('profiles').orderBy('createdAt', 'desc').limit(100);
  if (query && query.length > 0) {
    q = db
      .collection('profiles')
      .where('email', '>=', query)
      .where('email', '<=', `${query}`)
      .limit(100);
  }
  const snap = await q.get();

  const rows: ProfileRow[] = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const activePremium = await db
      .collection('profiles')
      .doc(doc.id)
      .collection('subscriptions')
      .where('active', '==', true)
      .where('tier', '==', 'premium')
      .limit(1)
      .get();
    rows.push({
      uid: doc.id,
      email: data.email ?? '',
      displayName: data.displayName ?? null,
      banned: data.banned === true,
      lastSeenAt: data.lastSeenAt?.toMillis?.() ?? null,
      createdAt: data.createdAt?.toMillis?.() ?? null,
      hasActivePremium: !activePremium.empty,
    });
  }
  return rows;
}

function relative(ms: number): string {
  const diff = Date.now() - ms;
  const s = Math.floor(diff / 1000);
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}
