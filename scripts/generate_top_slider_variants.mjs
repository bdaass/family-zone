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
 * Upload to Storage:
 *   node scripts/generate_top_slider_variants.mjs --upload
 *
 * Requires ADC for --upload: gcloud auth application-default login
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
const names = ['Male', 'Female', 'Boy', 'Girl', 'Solde'];
const locales = ['English', 'arabic'];

const SLOTS = {
  mobile: { width: 1000, height: 500 },
  web: { width: 2400, height: 440 },
};

const upload = process.argv.includes('--upload');

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

async function main() {
  let bucket;
  if (upload) {
    admin.initializeApp({ projectId: 'family-zone-2026', storageBucket: bucketName });
    bucket = admin.storage().bucket();
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
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
