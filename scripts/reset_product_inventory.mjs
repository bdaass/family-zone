#!/usr/bin/env node
/**
 * Resets size, colors, branchStock, and variantInventory on every product document.
 *
 * Usage:
 *   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/path/to/service-account.json"
 *   node scripts/reset_product_inventory.mjs
 *
 * Or after: gcloud auth application-default login
 */

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const projectId = process.env.FIREBASE_PROJECT_ID || 'family-zone-2026';

initializeApp({
  credential: applicationDefault(),
  projectId,
});

const db = getFirestore();

const patch = {
  size: FieldValue.delete(),
  colors: FieldValue.delete(),
  branchStock: FieldValue.delete(),
  variantInventory: {},
  stockQty: 0,
};

const snap = await db.collection('products').get();
let updated = 0;

for (const doc of snap.docs) {
  await doc.ref.update(patch);
  updated++;
  if (updated % 100 === 0) {
    console.log(`Updated ${updated}/${snap.size}...`);
  }
}

console.log(`Done. Reset inventory on ${updated} products in ${projectId}.`);
