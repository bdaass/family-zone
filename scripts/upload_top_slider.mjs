#!/usr/bin/env node
/**
 * Upload web/topSlider images to Firebase Storage.
 * Requires: gcloud auth application-default login
 * Run: node scripts/upload_top_slider.mjs
 */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const bucketName = 'family-zone-2026.firebasestorage.app';
const root = path.join(__dirname, '..', 'web', 'topSlider');

admin.initializeApp({ projectId: 'family-zone-2026', storageBucket: bucketName });

async function main() {
  const bucket = admin.storage().bucket();
  for (const locale of ['English', 'arabic']) {
    const dir = path.join(root, locale);
    if (!fs.existsSync(dir)) continue;
    for (const file of fs.readdirSync(dir)) {
      const local = path.join(dir, file);
      if (!fs.statSync(local).isFile()) continue;
      const remote = `topSlider/${locale}/${file}`;
      await bucket.upload(local, {
        destination: remote,
        metadata: { contentType: file.endsWith('.png') ? 'image/png' : 'image/jpeg' },
      });
      console.log('Uploaded', remote);
    }
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
