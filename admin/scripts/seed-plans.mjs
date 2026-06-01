// One-shot seed for the /plans Firestore collection.
//
// Usage (from admin/):
//   node --env-file=.env.local scripts/seed-plans.mjs
//
// Uses FIREBASE_SERVICE_ACCOUNT_JSON from .env.local (same secret the admin
// panel uses). Idempotent on plan name: re-running updates existing plans
// instead of creating duplicates.

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
if (!json) {
  console.error('FIREBASE_SERVICE_ACCOUNT_JSON not set. Run with:');
  console.error('  node --env-file=.env.local scripts/seed-plans.mjs');
  process.exit(1);
}

let credential;
try {
  const parsed = JSON.parse(json);
  // Vercel-friendly: normalize escaped \n in private_key back to real newlines.
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

const plans = [
  {
    name: '1 Month',
    durationDays: 30,
    priceInr: 40,
    currency: 'Rs',
    sortOrder: 1,
    active: true,
    popular: false,
    tagline: null,
  },
  {
    name: '3 Months',
    durationDays: 90,
    priceInr: 100,
    currency: 'Rs',
    sortOrder: 2,
    active: true,
    popular: true,
    tagline: 'Most popular',
  },
  {
    name: '1 Year',
    durationDays: 365,
    priceInr: 500,
    currency: 'Rs',
    sortOrder: 3,
    active: true,
    popular: false,
    tagline: 'Best value',
  },
];

const col = db.collection('plans');

console.log(`Seeding ${plans.length} plans into Firestore...`);
for (const p of plans) {
  // Idempotent: match by name. If a doc with this name already exists, update it.
  const existing = await col.where('name', '==', p.name).limit(1).get();
  if (!existing.empty) {
    const ref = existing.docs[0].ref;
    await ref.update({ ...p, updatedAt: FieldValue.serverTimestamp() });
    console.log(`  ✓ updated  ${p.name.padEnd(10)} (${ref.id})`);
  } else {
    const ref = await col.add({
      ...p,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    console.log(`  ✓ created  ${p.name.padEnd(10)} (${ref.id})`);
  }
}

console.log('Done.');
process.exit(0);
