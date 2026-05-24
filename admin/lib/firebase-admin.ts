// Firebase Admin SDK — server-only. Used by server actions to call Cloud
// Functions with elevated privilege and to verify the calling admin's ID token.

import 'server-only';
import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

let _app: App | null = null;
let _auth: Auth | null = null;
let _db: Firestore | null = null;

export function firebaseAdmin(): { app: App; auth: Auth; db: Firestore } {
  if (!_app) {
    const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!json) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON not set');
    }
    const credentials = JSON.parse(json) as {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    _app = getApps()[0] ?? initializeApp({
      credential: cert({
        projectId: credentials.project_id,
        clientEmail: credentials.client_email,
        // Vercel often stores newlines as \\n in env vars — normalize.
        privateKey: credentials.private_key.replace(/\\n/g, '\n'),
      }),
    });
    _auth = getAuth(_app);
    _db = getFirestore(_app);
  }
  return { app: _app!, auth: _auth!, db: _db! };
}
