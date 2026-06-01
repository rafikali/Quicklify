// Quick read of the /plans collection to confirm seed.
// Usage: node --env-file=.env.local scripts/list-plans.mjs

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const parsed = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
if (parsed.private_key) parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
if (!getApps().length) initializeApp({ credential: cert(parsed) });

const db = getFirestore();
const snap = await db.collection('plans').get();
const rows = snap.docs
  .map((d) => ({ id: d.id, ...d.data() }))
  .sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));

console.log(`${rows.length} plans in Firestore:\n`);
for (const r of rows) {
  console.log(
    `  [${r.sortOrder}] ${r.name.padEnd(10)} ${r.currency} ${r.priceInr.toString().padStart(4)}  ${r.durationDays}d  active=${r.active}  popular=${r.popular}  tagline=${r.tagline ?? '—'}`
  );
}
process.exit(0);
