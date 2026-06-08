// One-off: add an admin by email. Usage:
//   node scripts/add-admin.mjs <email>
//
// Loads FIREBASE_SERVICE_ACCOUNT_JSON from .env.local, looks up the Firebase
// Auth user by email, then writes admins/{uid} = { email, disabled: false,
// createdAt }. If the user has never signed in to Firebase Auth, prints a
// hint and exits non-zero.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Tiny .env.local loader (no dotenv dependency needed).
function loadEnv() {
  const path = join(__dirname, '..', '.env.local');
  const raw = readFileSync(path, 'utf8');
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (val.startsWith("'") && val.endsWith("'")) val = val.slice(1, -1);
    else if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1);
    process.env[key] = val;
  }
}

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error('Usage: node scripts/add-admin.mjs <email>');
    process.exit(1);
  }

  loadEnv();
  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!json) {
    console.error('FIREBASE_SERVICE_ACCOUNT_JSON not set in .env.local');
    process.exit(1);
  }
  const creds = JSON.parse(json);
  const app =
    getApps()[0] ??
    initializeApp({
      credential: cert({
        projectId: creds.project_id,
        clientEmail: creds.client_email,
        privateKey: creds.private_key.replace(/\\n/g, '\n'),
      }),
    });

  const auth = getAuth(app);
  const db = getFirestore(app);

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
  } catch (err) {
    if (err && err.code === 'auth/user-not-found') {
      console.error(`No Firebase Auth user exists for ${email}.`);
      console.error('Ask them to sign in once at https://quicklify-admin.vercel.app/login');
      console.error('(They will hit "not an admin" — that is expected. Then re-run this script.)');
      process.exit(2);
    }
    throw err;
  }

  const uid = userRecord.uid;
  const ref = db.collection('admins').doc(uid);
  const existing = await ref.get();
  if (existing.exists) {
    console.log(`Already an admin: ${email} (uid=${uid})`);
    if (existing.data()?.disabled === true) {
      await ref.update({ disabled: false });
      console.log('→ Re-enabled (was disabled).');
    }
    return;
  }

  await ref.set({
    email,
    disabled: false,
    addedBy: 'scripts/add-admin.mjs',
    createdAt: FieldValue.serverTimestamp(),
  });
  console.log(`Granted admin to ${email} (uid=${uid}).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
