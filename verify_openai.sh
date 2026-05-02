#!/bin/bash
# Calls OpenAI using the same secret pipeline as the app (sync .env → plist → curl).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
python3 "$ROOT/sync_openai_env.py"
KEY=$(python3 -c "import plistlib; from pathlib import Path; print(plistlib.load(open(Path('$ROOT')/'OpenAISecrets.plist','rb')).get('OPENAI_API_KEY',''))")
if [[ -z "${KEY// /}" ]]; then
  echo "OPENAI_API_KEY is empty after sync — put your key in .env as OPENAI_API_KEY=sk-… (no spaces around =) and save."
  exit 1
fi
RESP=$(curl -sS "https://api.openai.com/v1/chat/completions" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Say only: pong"}],"max_tokens":16}')
echo "$RESP" | python3 -c 'import sys,json
try:
  j=json.load(sys.stdin)
  print("API OK:", j["choices"][0]["message"]["content"].strip())
except Exception:
  import sys as s
  raw=s.stdin.read()
  print("API FAILED:", raw[:800])
  raise SystemExit(1)'
