#!/usr/bin/env node
/**
 * Build mobile (2:1) and web (~5.45:1) hero banners from Storage or local source masters.
 *
 * Sources (first match per file):
 *   gs://…/topSlider/{locale}/{Name}.jpg
 *   gs://…/web/topSlider/{locale}/{Name}.jpg
 *   web/topSlider/{locale}/{Name}.jpg  (local)
 *
 * Outputs:
 *   web/topSlider/{locale}/mobile/{Name}.jpg
 *   web/topSlider/{locale}/web/{Name}.jpg
 *
 * Generate local variants only:
 *   node scripts/generate_top_slider_variants.mjs
 *
 * Generate + upload to Firebase Storage:
 *   node scripts/generate_top_slider_variants.mjs --upload
 *
 * Upload existing local variants (skip regeneration):
 *   node scripts/generate_top_slider_variants.mjs --upload-only
 *
 * Auth for --upload / --upload-only (pick one):
 *   gcloud auth application-default login
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
 *   node scripts/generate_top_slider_variants.mjs --upload --service-account /path/to/key.json
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import sharp from 'sharp';
import admin from 'firebase-admin';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const webRoot = path.join(root, 'web', 'topSlider');
const bucketName = 'family-zone-2026.firebasestorage.app';
const projectId = 'family-zone-2026';
const names = ['Male', 'Female', 'Boy', 'Girl', 'Solde'];
const locales = ['English', 'arabic'];

const SLOTS = {
  mobile: { width: 1000, height: 500 },
  web: { width: 2400, height: 440 },
};

const argv = process.argv.slice(2);
const upload = argv.includes('--upload') || argv.includes('--upload-only');
const uploadOnly = argv.includes('--upload-only');

function readArg(flag) {
  const index = argv.indexOf(flag);
  if (index === -1 || index + 1 >= argv.length) return null;
  return argv[index + 1];
}

function printAuthHelp() {
  console.error(`
Upload requires Google Cloud credentials. Use one of:

  1) Application Default Credentials (opens browser once):
     gcloud auth application-default login
     node scripts/generate_top_slider_variants.mjs --upload-only

  2) Firebase service account JSON
     Firebase Console → Project settings → Service accounts → Generate new private key
     export GOOGLE_APPLICATION_CREDENTIALS="$HOME/Downloads/family-zone-2026-firebase-adminsdk.json"
     node scripts/generate_top_slider_variants.mjs --upload-only

  3) Pass the key file on the command line:
     node scripts/generate_top_slider_variants.mjs --upload-only \\
       --service-account "$HOME/Downloads/family-zone-2026-firebase-adminsdk.json"

Local files are already under web/topSlider/ — --upload-only skips regeneration.
`);
}

function initFirebaseAdmin() {
  const serviceAccountPath = readArg('--service-account') ?? process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (serviceAccountPath) {
    const resolved = path.resolve(serviceAccountPath);
    if (!fs.existsSync(resolved)) {
      console.error(`Service account file not found: ${resolved}`);
      process.exit(1);
    }
    const serviceAccount = JSON.parse(fs.readFileSync(resolved, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
      storageBucket: bucketName,
    });
    console.log('Using service account:', path.basename(resolved));
    return;
  }

  admin.initializeApp({ projectId, storageBucket: bucketName });
  console.log('Using Application Default Credentials (gcloud auth application-default login)');
}

async function cropToSlot(buffer, slot) {
  const { width: tw, height: th } = slot;
  const targetAspect = tw / th;
  const meta = await sharp(buffer).metadata();
  const srcAspect = meta.width / meta.height;

  let cropW;
  let cropH;
  let left;
  let top;

  if (srcAspect > targetAspect) {
    cropH = meta.height;
    cropW = Math.round(meta.height * targetAspect);
    left = Math.round((meta.width - cropW) / 2);
    top = 0;
  } else {
    cropW = meta.width;
    cropH = Math.round(meta.width / targetAspect);
    left = 0;
    top = Math.round((meta.height - cropH) / 2);
  }

  return sharp(buffer)
    .extract({ left, top, width: cropW, height: cropH })
    .resize(tw, th, { fit: 'fill' })
    .jpeg({ quality: 82, mozjpeg: true })
    .toBuffer();
}

async function readLocalSource(locale, name) {
  const local = path.join(webRoot, locale, `${name}.jpg`);
  if (!fs.existsSync(local)) return null;
  return fs.readFileSync(local);
}

async function readStorageSource(bucket, locale, name) {
  for (const prefix of [`topSlider/${locale}`, `web/topSlider/${locale}`]) {
    const object = `${prefix}/${name}.jpg`;
    const file = bucket.file(object);
    const [exists] = await file.exists();
    if (!exists) continue;
    const [buf] = await file.download();
    console.log('Source:', object);
    return buf;
  }
  return null;
}

async function writeOutputs(locale, name, mobileBuf, webBuf) {
  for (const [slot, buf] of [
    ['mobile', mobileBuf],
    ['web', webBuf],
  ]) {
    const dir = path.join(webRoot, locale, slot);
    fs.mkdirSync(dir, { recursive: true });
    const out = path.join(dir, `${name}.jpg`);
    fs.writeFileSync(out, buf);
    console.log('Wrote', path.relative(root, out));
  }
}

async function uploadOutputs(bucket, locale, name, mobileBuf, webBuf) {
  for (const [slot, buf] of [
    ['mobile', mobileBuf],
    ['web', webBuf],
  ]) {
    const remote = `topSlider/${locale}/${slot}/${name}.jpg`;
    await bucket.file(remote).save(buf, {
      metadata: { contentType: 'image/jpeg', cacheControl: 'public,max-age=3600' },
    });
    console.log('Uploaded', remote);
  }
}

async function readLocalVariant(locale, slot, name) {
  const local = path.join(webRoot, locale, slot, `${name}.jpg`);
  if (!fs.existsSync(local)) return null;
  return fs.readFileSync(local);
}

async function uploadExistingVariants(bucket) {
  let uploaded = 0;

  for (const locale of locales) {
    for (const name of names) {
      const mobileBuf = await readLocalVariant(locale, 'mobile', name);
      const webBuf = await readLocalVariant(locale, 'web', name);
      if (!mobileBuf || !webBuf) {
        console.warn('Skip upload (missing local variant):', locale, name);
        continue;
      }
      await uploadOutputs(bucket, locale, name, mobileBuf, webBuf);
      uploaded += 2;
    }
  }

  if (uploaded === 0) {
    console.error('No local variants found under web/topSlider/. Run without --upload-only first.');
    process.exit(1);
  }

  console.log(`Done — uploaded ${uploaded} files to gs://${bucketName}/topSlider/`);
}

async function main() {
  let bucket;
  if (upload) {
    initFirebaseAdmin();
    bucket = admin.storage().bucket();
  }

  if (uploadOnly) {
    await uploadExistingVariants(bucket);
    return;
  }

  for (const locale of locales) {
    for (const name of names) {
      let source = await readLocalSource(locale, name);
      if (!source && bucket) {
        source = await readStorageSource(bucket, locale, name);
      }
      if (!source) {
        console.warn('Skip (no source):', locale, name);
        continue;
      }

      const mobileBuf = await cropToSlot(source, SLOTS.mobile);
      const webBuf = await cropToSlot(source, SLOTS.web);
      await writeOutputs(locale, name, mobileBuf, webBuf);
      if (bucket) await uploadOutputs(bucket, locale, name, mobileBuf, webBuf);
    }
  }

  if (upload) {
    console.log(`Done — uploaded hero banners to gs://${bucketName}/topSlider/`);
  }
}

main().catch((err) => {
  const message = err?.message ?? String(err);
  if (message.includes('default credentials') || message.includes('Could not load the default credentials')) {
    printAuthHelp();
    process.exit(1);
  }
  console.error(err);
  process.exit(1);
});
