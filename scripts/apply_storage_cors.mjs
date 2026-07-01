#!/usr/bin/env node
/**
 * Applies cors.json to Firebase Storage (optional — Edge images work without this
 * after the DomNetworkImage fix; CORS helps if you use fetch-based image loading).
 *
 * Auth (pick one):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json node scripts/apply_storage_cors.mjs
 *   node scripts/apply_storage_cors.mjs --key=/path/to/service-account.json
 *
 * Get a service account key:
 *   Firebase Console → Project settings → Service accounts → Generate new private key
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const bucketName = 'family-zone-2026.firebasestorage.app';
const cors = JSON.parse(readFileSync(join(root, 'cors.json'), 'utf8'));

const keyArg = process.argv.find((a) => a.startsWith('--key='))?.slice('--key='.length);
const keyPath = keyArg || process.env.GOOGLE_APPLICATION_CREDENTIALS;

function printAuthHelp() {
  console.error(`
Could not authenticate to Google Cloud.

1. Open Firebase Console → Project settings → Service accounts
2. Click "Generate new private key" and save the JSON file
3. Run:

   GOOGLE_APPLICATION_CREDENTIALS="$HOME/Downloads/family-zone-2026-firebase-adminsdk.json" \\
     node scripts/apply_storage_cors.mjs

Or:

   node scripts/apply_storage_cors.mjs --key="$HOME/Downloads/family-zone-2026-firebase-adminsdk.json"

(You do NOT need gcloud for this. Edge product images work without CORS after redeploying the app.)
`);
}

if (!admin.apps.length) {
  if (keyPath) {
    const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: bucketName,
    });
  } else {
    try {
      admin.initializeApp({ storageBucket: bucketName });
    } catch (e) {
      printAuthHelp();
      process.exit(1);
    }
  }
}

try {
  const bucket = admin.storage().bucket();
  await bucket.setMetadata({ cors });
  const [metadata] = await bucket.getMetadata();
  console.log(`CORS applied to gs://${bucketName}`);
  console.log(JSON.stringify(metadata.cors ?? [], null, 2));
} catch (e) {
  if (String(e).includes('NO_ADC_FOUND') || String(e).includes('Could not load the default credentials')) {
    printAuthHelp();
    process.exit(1);
  }
  throw e;
}
