#!/usr/bin/env bash
# Apply CORS to Firebase Storage so skwasm can fetch product images (Edge / Firefox).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if command -v node >/dev/null 2>&1 && [[ -d "$ROOT/scripts/node_modules" ]]; then
  node "$ROOT/scripts/apply_storage_cors.mjs"
  exit 0
fi

BUCKET="gs://family-zone-2026.firebasestorage.app"
if command -v gcloud >/dev/null 2>&1; then
  gcloud storage buckets update "$BUCKET" --cors-file="$ROOT/cors.json"
  gcloud storage buckets describe "$BUCKET" --format="json(cors)"
  exit 0
fi

if command -v gsutil >/dev/null 2>&1; then
  gsutil cors set "$ROOT/cors.json" "$BUCKET"
  gsutil cors get "$BUCKET"
  exit 0
fi

echo "Could not apply Storage CORS. Install Node deps (cd scripts && npm install) or gcloud, then run:" >&2
echo "  node scripts/apply_storage_cors.mjs" >&2
exit 1
