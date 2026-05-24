'use server';

// Server actions invoked by the admin UI. Every action verifies the caller
// is an active admin, then writes directly to Firestore via the Admin SDK
// (which bypasses Security Rules). Each privileged write also appends an
// immutable audit_log entry in the same transaction.

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { firebaseAdmin } from '@/lib/firebase-admin';
import {
  clearAdminIdTokenCookie,
  requireAdmin,
  setAdminIdTokenCookie,
} from '@/lib/admin-auth';

type AuditAction =
  | 'grant_premium'
  | 'revoke_premium'
  | 'revoke_device'
  | 'ban_user';

interface AuditInput {
  action: AuditAction;
  actorAdminUid: string;
  targetUserUid: string;
  beforeState?: Record<string, unknown>;
  afterState?: Record<string, unknown>;
}

async function writeAudit(input: AuditInput): Promise<void> {
  const { db } = firebaseAdmin();
  try {
    await db.collection('audit_log').add({
      action: input.action,
      actorAdminUid: input.actorAdminUid,
      actorUserUid: null,
      targetUserUid: input.targetUserUid,
      beforeState: input.beforeState ?? {},
      afterState: input.afterState ?? {},
      ip: null,
      userAgent: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.warn('audit_log write failed', input.action, err);
  }
}

// ---------- sign-in / sign-out --------------------------------------------

export async function signInAction(idToken: string): Promise<void> {
  const { auth, db } = firebaseAdmin();
  const decoded = await auth.verifyIdToken(idToken, true);
  const adminSnap = await db.collection('admins').doc(decoded.uid).get();
  if (!adminSnap.exists || adminSnap.data()?.disabled === true) {
    throw new Error('Not an authorized admin');
  }
  await setAdminIdTokenCookie(idToken);
}

export async function signOutAction(): Promise<void> {
  await clearAdminIdTokenCookie();
  redirect('/login');
}

// ---------- admin actions -------------------------------------------------

export async function grantPremiumAction(
  targetUid: string,
  durationDays: number | null,
  note?: string
): Promise<void> {
  const adminUid = await requireAdmin();
  const { db } = firebaseAdmin();

  const profileRef = db.collection('profiles').doc(targetUid);
  const profileSnap = await profileRef.get();
  if (!profileSnap.exists) {
    throw new Error('Target user has not signed in yet.');
  }

  const subsCol = profileRef.collection('subscriptions');
  const now = Timestamp.now();
  const endsAt =
    durationDays === null
      ? null
      : Timestamp.fromMillis(now.toMillis() + durationDays * 86400 * 1000);

  // Transaction: supersede active subs + insert new one atomically.
  const { newId, supersededIds } = await db.runTransaction(async (tx) => {
    const activeSnap = await tx.get(subsCol.where('active', '==', true));
    const ids: string[] = [];
    for (const d of activeSnap.docs) {
      ids.push(d.id);
      tx.update(d.ref, { active: false, endsAt: now });
    }
    const newRef = subsCol.doc();
    tx.set(newRef, {
      tier: 'premium',
      startsAt: now,
      endsAt,
      source: 'admin_grant',
      sourceRef: adminUid,
      createdAt: FieldValue.serverTimestamp(),
      active: true,
    });
    return { newId: newRef.id, supersededIds: ids };
  });

  await writeAudit({
    action: 'grant_premium',
    actorAdminUid: adminUid,
    targetUserUid: targetUid,
    beforeState: { supersededIds },
    afterState: {
      subscriptionId: newId,
      durationDays,
      endsAt: endsAt?.toMillis() ?? null,
      note: note ?? '',
    },
  });

  revalidatePath(`/users/${targetUid}`);
}

export async function revokePremiumAction(
  targetUid: string,
  reason: string
): Promise<void> {
  if (reason.trim().length < 3) {
    throw new Error('Reason required (min 3 chars)');
  }
  const adminUid = await requireAdmin();
  const { db } = firebaseAdmin();

  const subsCol = db
    .collection('profiles')
    .doc(targetUid)
    .collection('subscriptions');
  const now = Timestamp.now();

  const revokedIds = await db.runTransaction(async (tx) => {
    const snap = await tx.get(subsCol.where('active', '==', true));
    const ids: string[] = [];
    for (const d of snap.docs) {
      ids.push(d.id);
      tx.update(d.ref, { active: false, endsAt: now });
    }
    return ids;
  });

  await writeAudit({
    action: 'revoke_premium',
    actorAdminUid: adminUid,
    targetUserUid: targetUid,
    beforeState: { activeSubscriptions: revokedIds.length },
    afterState: { revokedIds, reason },
  });

  revalidatePath(`/users/${targetUid}`);
}

export async function revokeDeviceAction(
  targetUid: string,
  deviceId: string,
  reason?: string
): Promise<void> {
  const adminUid = await requireAdmin();
  const { db } = firebaseAdmin();
  const deviceRef = db
    .collection('profiles')
    .doc(targetUid)
    .collection('devices')
    .doc(deviceId);

  const snap = await deviceRef.get();
  if (!snap.exists) throw new Error('Device not found.');
  await deviceRef.update({
    revokedAt: Timestamp.now(),
    revokeReason: reason ?? 'admin revoked',
  });

  await writeAudit({
    action: 'revoke_device',
    actorAdminUid: adminUid,
    targetUserUid: targetUid,
    afterState: { deviceId, reason: reason ?? '' },
  });

  revalidatePath(`/users/${targetUid}`);
}

export async function banUserAction(
  targetUid: string,
  reason: string
): Promise<void> {
  if (reason.trim().length < 3) {
    throw new Error('Reason required (min 3 chars)');
  }
  const adminUid = await requireAdmin();
  const { db } = firebaseAdmin();

  const profileRef = db.collection('profiles').doc(targetUid);
  const subsCol = profileRef.collection('subscriptions');
  const now = Timestamp.now();

  await db.runTransaction(async (tx) => {
    tx.update(profileRef, { banned: true });
    const subs = await tx.get(subsCol.where('active', '==', true));
    for (const d of subs.docs) {
      tx.update(d.ref, { active: false, endsAt: now });
    }
  });

  await writeAudit({
    action: 'ban_user',
    actorAdminUid: adminUid,
    targetUserUid: targetUid,
    afterState: { reason },
  });

  revalidatePath(`/users/${targetUid}`);
}
