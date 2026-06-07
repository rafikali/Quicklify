import Link from 'next/link';
import { redirect } from 'next/navigation';
import { firebaseAdmin } from '@/lib/firebase-admin';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { HowToNote } from '@/components/how-to-note';

interface AuditRow {
  id: string;
  action: string;
  actorAdminUid: string | null;
  actorUserUid: string | null;
  targetUserUid: string | null;
  createdAt: number | null;
  afterState: Record<string, unknown>;
}

export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<{ action?: string }>;
}) {
  const adminUid = await getCurrentAdminUid();
  if (!adminUid) redirect('/login');
  const { action } = await searchParams;
  const rows = await loadAudit(action);

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">Audit log (last 200)</h1>

      <HowToNote
        whatToDo={[
          'This is a read-only log of every admin action. You cannot edit or delete entries here.',
          'Use the "Filter by action" dropdown to narrow down (e.g. only grant_premium events).',
          'Click any "target" user link to jump to that user profile.',
          'Use this log to investigate "who did what" — e.g. who granted free premium to a friend, or who revoked a paying user by mistake.',
        ]}
        howToVerify={[
          'Perform any admin action elsewhere (grant premium to a test user, ban a device, etc.).',
          'Come back here and reload — the new entry should be at the top of the list with your admin uid as actor and the affected user as target.',
        ]}
        tip="This log is append-only at the database level (rules block updates/deletes) so even with admin Firestore access nobody can rewrite history without the service account."
      />

      <form className="mb-6" action="/audit" method="GET">
        <select
          name="action"
          defaultValue={action ?? ''}
          className="bg-card border border-border rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All actions</option>
          <option value="grant_premium">grant_premium</option>
          <option value="revoke_premium">revoke_premium</option>
          <option value="revoke_device">revoke_device</option>
          <option value="ban_user">ban_user</option>
          <option value="register_device">register_device</option>
        </select>
        <button className="ml-2 text-muted hover:text-text text-sm">Filter</button>
      </form>

      <div className="space-y-2">
        {rows.length === 0 && (
          <div className="text-muted text-sm">No audit entries.</div>
        )}
        {rows.map((r) => (
          <div key={r.id} className="bg-card border border-border rounded p-3 text-sm">
            <div className="flex items-center justify-between">
              <code className="text-primary">{r.action}</code>
              <span className="text-muted text-xs">
                {r.createdAt ? new Date(r.createdAt).toLocaleString() : '—'}
              </span>
            </div>
            <div className="text-muted text-xs mt-1">
              By{' '}
              {r.actorAdminUid
                ? `admin ${r.actorAdminUid.slice(0, 8)}…`
                : r.actorUserUid
                ? 'user'
                : 'system'}
              {' · target: '}
              {r.targetUserUid ? (
                <Link
                  href={`/users/${r.targetUserUid}`}
                  className="text-primary hover:underline"
                >
                  {r.targetUserUid.slice(0, 8)}…
                </Link>
              ) : (
                '—'
              )}
            </div>
            {Object.keys(r.afterState).length > 0 && (
              <pre className="text-xs text-muted mt-2 overflow-x-auto">
                {JSON.stringify(r.afterState, null, 2)}
              </pre>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

async function loadAudit(action: string | undefined): Promise<AuditRow[]> {
  const { db } = firebaseAdmin();
  let q = db.collection('audit_log').orderBy('createdAt', 'desc').limit(200);
  if (action) {
    q = db
      .collection('audit_log')
      .where('action', '==', action)
      .orderBy('createdAt', 'desc')
      .limit(200);
  }
  const snap = await q.get();
  return snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      action: data.action ?? '',
      actorAdminUid: data.actorAdminUid ?? null,
      actorUserUid: data.actorUserUid ?? null,
      targetUserUid: data.targetUserUid ?? null,
      createdAt: data.createdAt?.toMillis?.() ?? null,
      afterState: (data.afterState ?? {}) as Record<string, unknown>,
    };
  });
}
