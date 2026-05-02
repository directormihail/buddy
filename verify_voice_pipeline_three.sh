#!/bin/bash
# Three automated checks for voice + build (speech itself must be tested on a real device).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PBX="$ROOT/Buddy.xcodeproj/project.pbxproj"

run_check() {
  local n="$1"
  echo ""
  echo "========== VOICE PIPELINE CHECK $n / 3 =========="
  case "$n" in
    1)
      grep -q 'INFOPLIST_KEY_NSMicrophoneUsageDescription' "$PBX" || { echo "FAIL: missing Microphone usage string in project"; exit 1; }
      grep -q 'INFOPLIST_KEY_NSSpeechRecognitionUsageDescription' "$PBX" || { echo "FAIL: missing Speech Recognition usage string"; exit 1; }
      echo "OK: Privacy usage strings present in Xcode project."
      ;;
    2)
      python3 "$ROOT/sync_openai_env.py"
      python3 -c "import plistlib; from pathlib import Path; d=plistlib.load(open(Path('$ROOT')/'OpenAISecrets.plist','rb')); assert len(d.get('OPENAI_API_KEY',''))>10; print('OK: OpenAISecrets.plist has API key for server replies after speech.')"
      ;;
    3)
      xcodebuild -scheme Buddy -project "$ROOT/Buddy.xcodeproj" -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build
      echo "OK: Buddy target builds with Speech + AVFoundation stack."
      ;;
  esac
}

for i in 1 2 3; do
  run_check "$i"
done
echo ""
echo "All 3 pipeline checks passed. Test speech-to-text on a physical iPhone (Simulator speech is limited)."
