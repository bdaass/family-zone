#!/usr/bin/env node
/**
 * Seeds Firestore app_config/mobile using your existing `firebase login` session.
 * No gcloud required.
 *
 * Prerequisite:
 *   firebase login
 *
 * Usage (from project root):
 *   node scripts/seed_app_config.mjs
 */
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');

function resolveFirebaseToolsRoot() {
  try {
    const globalRoot = execSync('npm root -g', { encoding: 'utf8' }).trim();
    return join(globalRoot, 'firebase-tools');
  } catch (_) {
    return join(projectRoot, 'functions/node_modules/firebase-tools');
  }
}

const firebaseToolsRoot = resolveFirebaseToolsRoot();
const requireFt = createRequire(join(firebaseToolsRoot, 'package.json'));
const auth = requireFt('./lib/auth');
const { requireAuth } = requireFt('./lib/requireAuth');
const scopes = requireFt('./lib/scopes');

const projectId = 'family-zone-2026';

const doc = {
  current_version: '1.0.0',
  force_update: false,
  android_store_url: 'https://play.google.com/store/apps/details?id=com.familyzone.shop',
  ios_store_url: '',
};

async function getFirebaseAccessToken() {
  const account = auth.getProjectDefaultAccount(projectRoot) ?? auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('Not logged in to Firebase CLI. Run: firebase login');
  }

  const options = {
    ...account,
    authScopes: [scopes.CLOUD_PLATFORM],
  };
  await requireAuth(options);
  const tokens = await auth.getAccessToken(account.tokens.refresh_token, options.authScopes);
  return tokens.access_token;
}

function toFirestoreFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    if (typeof value === 'boolean') {
      fields[key] = { booleanValue: value };
    } else {
      fields[key] = { stringValue: String(value) };
    }
  }
  return fields;
}

async function upsertDocument(accessToken) {
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
  };
  const body = JSON.stringify({ fields: toFirestoreFields(doc) });

  const patchUrl = `${baseUrl}/app_config/mobile?` +
    Object.keys(doc).map((k) => `updateMask.fieldPaths=${k}`).join('&');

  let response = await fetch(patchUrl, { method: 'PATCH', headers, body });
  if (response.ok) return;

  if (response.status !== 404) {
    const text = await response.text();
    throw new Error(`Firestore write failed (${response.status}): ${text}`);
  }

  response = await fetch(`${baseUrl}/app_config?documentId=mobile`, {
    method: 'POST',
    headers,
    body,
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Firestore create failed (${response.status}): ${text}`);
  }
}

const accessToken = await getFirebaseAccessToken();
await upsertDocument(accessToken);

console.log(`Seeded ${projectId} → app_config/mobile`);
console.log(JSON.stringify(doc, null, 2));
