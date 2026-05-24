// Server-side admin verification.
//
// Each privileged server action verifies the calling user is an active admin
// by checking the admins/{uid} doc with the Admin SDK. Front-end gates are
// belt-and-suspenders; the server check is the one that actually matters.

import 'server-only';
import { cookies } from 'next/headers';
import { firebaseAdmin } from './firebase-admin';

const ID_TOKEN_COOKIE = 'qlf_admin_id_token';

export async function setAdminIdTokenCookie(idToken: string): Promise<void> {
  const jar = await cookies();
  jar.set({
    name: ID_TOKEN_COOKIE,
    value: idToken,
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60, // 1h
  });
}

export async function clearAdminIdTokenCookie(): Promise<void> {
  const jar = await cookies();
  jar.delete(ID_TOKEN_COOKIE);
}

export async function getCurrentAdminUid(): Promise<string | null> {
  const jar = await cookies();
  const token = jar.get(ID_TOKEN_COOKIE)?.value;
  if (!token) return null;
  try {
    const { auth, db } = firebaseAdmin();
    const decoded = await auth.verifyIdToken(token, true);
    // Confirm admins/{uid} exists and is not disabled.
    const adminSnap = await db.collection('admins').doc(decoded.uid).get();
    if (!adminSnap.exists) return null;
    if (adminSnap.data()?.disabled === true) return null;
    return decoded.uid;
  } catch {
    return null;
  }
}

/** Throw if caller is not an active admin. Use at the top of every server action. */
export async function requireAdmin(): Promise<string> {
  const uid = await getCurrentAdminUid();
  if (!uid) throw new Error('Not authorized');
  return uid;
}
