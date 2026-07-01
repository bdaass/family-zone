#!/usr/bin/env bash
# Post-build web tuning:
# - Enable skwasm on Firefox (gecko) for fast loads
# - Chromium CanvasKit fallback for Chrome/Safari when skwasm is unavailable
# - Strip broken sourceMappingURL comments (Firebase SPA rewrite serves HTML for missing .map files)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_DIR="$ROOT/build/web"
BOOTSTRAP="$WEB_DIR/flutter_bootstrap.js"

if [[ ! -f "$BOOTSTRAP" ]]; then
  echo "Missing $BOOTSTRAP — run flutter build web first." >&2
  exit 1
fi

python3 - "$BOOTSTRAP" "$WEB_DIR" <<'PY'
import re
import sys
from pathlib import Path

bootstrap = Path(sys.argv[1])
web_dir = Path(sys.argv[2])
text = bootstrap.read_text()

# Upgrade older patches that disabled Firefox skwasm.
text = text.replace("gecko: false", "gecko: true")

marker = 'canvasKitVariant: "chromium"'
if marker not in text:
    needle = "_flutter.loader.load({\n  serviceWorkerSettings:"
    if needle not in text:
        needle = "_flutter.loader.load({"
    replacement = """_flutter.loader.load({
  config: {
    canvasKitVariant: "chromium",
    wasmAllowList: {
      blink: true,
      gecko: true,
      webkit: true,
    },
  },
  serviceWorkerSettings:"""
    if needle == "_flutter.loader.load({":
        text = text.replace(needle, replacement.rstrip("serviceWorkerSettings:"), 1)
    else:
        text = text.replace(needle, replacement, 1)
    print(f"Patched {bootstrap} (skwasm for all engines + chromium CanvasKit fallback)")
else:
    print(f"Bootstrap config already present: {bootstrap}")

bootstrap.write_text(text)

source_map_re = re.compile(r"//[#@] sourceMappingURL=.*$", re.MULTILINE)
stripped = []
for pattern in ("*.js", "*.mjs"):
    for path in sorted(web_dir.glob(pattern)):
        original = path.read_text()
        cleaned = source_map_re.sub("", original).rstrip() + "\n"
        if cleaned != original:
            path.write_text(cleaned)
            stripped.append(path.name)

if stripped:
    print(f"Removed broken source map refs from: {', '.join(stripped)}")
else:
    print("No source map comments to strip")
PY
