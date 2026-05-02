#!/bin/bash
# Runs the same check as the app: sync .env → plist, then 3 live OpenAI pings.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
python3 "$ROOT/sync_openai_env.py"
for i in 1 2 3; do
  echo ""
  echo "========== TEST RUN $i / 3 =========="
  bash "$ROOT/verify_openai.sh"
done
echo ""
echo "All 3 API checks passed."
