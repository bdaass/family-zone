#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter build web --release \
  --pwa-strategy=none \
  --no-web-resources-cdn

"$ROOT/scripts/patch_web_build.sh"

# Optional: Storage CORS (not required for Edge images after DomNetworkImage fix).
"$ROOT/scripts/apply_storage_cors.sh" || true

firebase deploy --only hosting

echo "Deployed https://family-zone-2026.web.app"
