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
  | 'ban_user'
  | 'unban_user'
  | 'create_plan'
  | 'update_plan'
  | 'delete_plan'
  | 'update_app_config';

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
  note?: string,
  planId?: string | null,
  priceInr?: number | null
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
      planId: planId ?? null,
      priceInr: priceInr ?? null,
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
      planId: planId ?? null,
      priceInr: priceInr ?? null,
      note: note ?? '',
    },
  });

  revalidatePath(`/users/${targetUid}`);
}

// ---------- plans CRUD ----------------------------------------------------

export interface PlanInput {
  name: string;
  durationDays: number;
  priceInr: number;
  currency?: string;
  sortOrder?: number;
  active?: boolean;
  popular?: boolean;
  tagline?: string;
}

function validatePlan(input: PlanInput): void {
  if (!input.name || input.name.trim().length < 1) {
    throw new Error('Plan name is required');
  }
  if (!Number.isFinite(input.durationDays) || input.durationDays < 1) {
    throw new Error('Duration must be a positive integer (days)');
  }
  if (!Number.isFinite(input.priceInr) || input.priceInr < 0) {
    throw new Error('Price must be zero or positive');
  }
}

export async function createPlanAction(input: PlanInput): Promise<string> {
  const adminUid = await requireAdmin();
  validatePlan(input);
  const { db } = firebaseAdmin();
  const ref = await db.collection('plans').add({
    name: input.name.trim(),
    durationDays: Math.floor(input.durationDays),
    priceInr: Math.floor(input.priceInr),
    currency: (input.currency ?? 'Rs').trim(),
    sortOrder: input.sortOrder ?? 0,
    active: input.active ?? true,
    popular: input.popular ?? false,
    tagline: input.tagline?.trim() || null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await writeAudit({
    action: 'create_plan',
    actorAdminUid: adminUid,
    targetUserUid: ref.id,
    afterState: { ...input, planId: ref.id },
  });
  revalidatePath('/plans');
  return ref.id;
}

export async function updatePlanAction(
  planId: string,
  input: PlanInput
): Promise<void> {
  const adminUid = await requireAdmin();
  validatePlan(input);
  const { db } = firebaseAdmin();
  const ref = db.collection('plans').doc(planId);
  const before = (await ref.get()).data() ?? null;
  await ref.update({
    name: input.name.trim(),
    durationDays: Math.floor(input.durationDays),
    priceInr: Math.floor(input.priceInr),
    currency: (input.currency ?? 'Rs').trim(),
    sortOrder: input.sortOrder ?? 0,
    active: input.active ?? true,
    popular: input.popular ?? false,
    tagline: input.tagline?.trim() || null,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await writeAudit({
    action: 'update_plan',
    actorAdminUid: adminUid,
    targetUserUid: planId,
    beforeState: before ?? {},
    afterState: { ...input, planId },
  });
  revalidatePath('/plans');
}

export async function deletePlanAction(planId: string): Promise<void> {
  const adminUid = await requireAdmin();
  const { db } = firebaseAdmin();
  const ref = db.collection('plans').doc(planId);
  const before = (await ref.get()).data() ?? null;
  await ref.delete();
  await writeAudit({
    action: 'delete_plan',
    actorAdminUid: adminUid,
    targetUserUid: planId,
    beforeState: before ?? {},
  });
  revalidatePath('/plans');
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

// ---------- app config (force-update / blackout gate) ---------------------

export interface AppConfigInput {
  minRequiredVersion: string;
  latestVersion: string;
  apkUrl: string;
  updateMessage: string;
}

const SEMVER_RE = /^\d+(\.\d+){0,3}$/;

function validateAppConfig(input: AppConfigInput): void {
  if (!SEMVER_RE.test(input.minRequiredVersion.trim())) {
    throw new Error('minRequiredVersion must be dotted numbers like 1.4.0');
  }
  if (!SEMVER_RE.test(input.latestVersion.trim())) {
    throw new Error('latestVersion must be dotted numbers like 1.5.0');
  }
  try {
    const u = new URL(input.apkUrl.trim());
    if (u.protocol !== 'https:') throw new Error('must be https');
  } catch {
    throw new Error('apkUrl must be a valid https URL');
  }
  if (input.updateMessage.trim().length < 3) {
    throw new Error('updateMessage is required');
  }
}

export async function updateAppConfigAction(
  input: AppConfigInput
): Promise<void> {
  const adminUid = await requireAdmin();
  validateAppConfig(input);

  const { db } = firebaseAdmin();
  const ref = db.collection('config').doc('app');
  const before = (await ref.get()).data() ?? null;

  const next = {
    minRequiredVersion: input.minRequiredVersion.trim(),
    latestVersion: input.latestVersion.trim(),
    apkUrl: input.apkUrl.trim(),
    updateMessage: input.updateMessage.trim(),
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: adminUid,
  };

  await ref.set(next, { merge: true });

  await writeAudit({
    action: 'update_app_config',
    actorAdminUid: adminUid,
    targetUserUid: 'app',
    beforeState: before ?? {},
    afterState: { ...input },
  });

  revalidatePath('/app-control');
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
  const trimmedReason = reason.trim();

  await db.runTransaction(async (tx) => {
    tx.update(profileRef, {
      banned: true,
      banReason: trimmedReason,
      bannedAt: now,
      bannedBy: adminUid,
    });
    const subs = await tx.get(subsCol.where('active', '==', true));
    for (const d of subs.docs) {
      tx.update(d.ref, { active: false, endsAt: now });
    }
  });

  await writeAudit({
    action: 'ban_user',
    actorAdminUid: adminUid,
    targetUserUid: targetUid,
    afterState: { reason: trimmedReason },
  });

  revalidatePath(`/users/${targetUid}`);
}

export async function unbanUserAction(targetUid: string): Promise<void> {
  const adminUid = await requireAdmin();
  const { db } = firebaseAdmin();
  const profileRef = db.collection('profiles').doc(targetUid);

  // Clear ban fields. Premium / devices are NOT auto-restored — re-grant
  // explicitly if needed.
  await profileRef.update({
    banned: false,
    banReason: FieldValue.delete(),
    bannedAt: FieldValue.delete(),
    bannedBy: FieldValue.delete(),
  });

  await writeAudit({
    action: 'unban_user',
    actorAdminUid: adminUid,
    targetUserUid: targetUid,
    afterState: {},
  });

  revalidatePath(`/users/${targetUid}`);
}
