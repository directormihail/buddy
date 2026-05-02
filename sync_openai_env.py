#!/usr/bin/env python3
"""Writes OPENAI_API_KEY from repo-root .env into OpenAISecrets.plist before compile."""
import os
import plistlib
import re
from pathlib import Path


def parse_openai_key(text: str) -> str:
    """Last non-empty OPENAI_API_KEY wins; tolerates BOM, export, spaces around =."""
    last = ""
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        # OPENAI_API_KEY = value  OR  OPENAI_API_KEY=value
        m = re.match(r"^OPENAI_API_KEY\s*=\s*(.*)$", line)
        if not m:
            continue
        val = m.group(1).strip().strip('"').strip("'")
        if val:
            last = val
    return last


def main() -> None:
    srcroot = Path(os.environ.get("SRCROOT", ".")).resolve()
    env_path = srcroot / ".env"
    plist_path = srcroot / "OpenAISecrets.plist"

    key = ""
    if env_path.is_file():
        text = env_path.read_text(encoding="utf-8-sig")
        key = parse_openai_key(text)

    plist_path.parent.mkdir(parents=True, exist_ok=True)
    with open(plist_path, "wb") as fp:
        plistlib.dump({"OPENAI_API_KEY": key}, fp)


if __name__ == "__main__":
    main()
