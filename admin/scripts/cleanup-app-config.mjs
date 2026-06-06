// One-shot cleanup: remove obsolete blackoutEnabled / blackoutMessage from
// config/app (now handled per-user via profiles/{uid}.banned).
//
// Usage (from admin/):
//   node --env-file=.env.local scripts/cleanup-app-config.mjs

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
if (!json) {
  console.error('FIREBASE_SERVICE_ACCOUNT_JSON not set.');
  process.exit(1);
}
const parsed = JSON.parse(json);
if (parsed.private_key) {
  parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
}
if (!getApps().length) initializeApp({ credential: cert(parsed) });

const db = getFirestore();
const ref = db.collection('config').doc('app');
await ref.update({
  blackoutEnabled: FieldValue.delete(),
  blackoutMessage: FieldValue.delete(),
  updatedAt: FieldValue.serverTimestamp(),
});

const after = (await ref.get()).data();
console.log('config/app after cleanup:');
console.log(JSON.stringify(after, null, 2));
process.exit(0);
