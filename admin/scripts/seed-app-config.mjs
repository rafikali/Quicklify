// One-shot seed for the config/app document (force-update + blackout gate).
//
// Usage (from admin/):
//   node --env-file=.env.local scripts/seed-app-config.mjs
//
// Safe to re-run: uses merge:true, so it only fills in missing fields and
// leaves any existing admin-edited values intact.

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
if (!json) {
  console.error('FIREBASE_SERVICE_ACCOUNT_JSON not set. Run with:');
  console.error('  node --env-file=.env.local scripts/seed-app-config.mjs');
  process.exit(1);
}

let credential;
try {
  const parsed = JSON.parse(json);
  if (parsed.private_key && typeof parsed.private_key === 'string') {
    parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
  }
  credential = cert(parsed);
} catch (e) {
  console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON:', e.message);
  process.exit(1);
}

if (!getApps().length) {
  initializeApp({ credential });
}
const db = getFirestore();

const defaults = {
  minRequiredVersion: '0.0.0',
  latestVersion: '1.0.0',
  apkUrl: 'https://quicklify-murex.vercel.app/downloads/quicklify-latest.apk',
  updateMessage:
    'A new version of Quicklify is required. Please download the latest APK to continue.',
};

const ref = db.collection('config').doc('app');
const snap = await ref.get();

if (snap.exists) {
  console.log('config/app already exists — only filling missing fields.');
  await ref.set(
    { ...defaults, updatedAt: FieldValue.serverTimestamp() },
    { merge: true }
  );
} else {
  console.log('Creating config/app with defaults…');
  await ref.set({
    ...defaults,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

const final = (await ref.get()).data();
console.log('config/app current state:');
console.log(JSON.stringify(final, null, 2));
process.exit(0);
