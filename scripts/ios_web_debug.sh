#!/usr/bin/env bash
# Local iOS-web simulation: forces iOS code paths (?fz_ios=1) on desktop browser.
# Best verification: Safari on a real iPhone, or Xcode → iOS Simulator → Safari.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${FZ_WEB_PORT:-7357}"
echo "Starting Family Zone web on port $PORT…"
echo ""
echo "  iOS mode (forced):  http://127.0.0.1:$PORT/?fz_ios=1"
echo "  Normal desktop:     http://127.0.0.1:$PORT/"
echo ""
echo "Stress test: open iOS URL, scroll the catalog for 2+ minutes."
echo "If the tab reloads, WebKit ran out of memory (same as client crash)."
echo "Safari Mac Responsive Design Mode is NOT the same as iPhone memory limits."
echo ""

flutter run -d web-server --web-port="$PORT" --web-hostname=127.0.0.1
