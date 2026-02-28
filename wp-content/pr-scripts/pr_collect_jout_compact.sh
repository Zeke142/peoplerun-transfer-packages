#!/usr/bin/env bash
# run collector then compact into one JSON line (use jq if available)
TMP=/tmp/pr_jout_raw.$$
DEST=/tmp/pr_jout_compact.$$
python3 ./wp-content/pr-scripts/pr_collect_jout.py > "$TMP" 2>/dev/null || true
if command -v jq >/dev/null 2>&1; then
  jq -c . "$TMP" > "$DEST" 2>/dev/null || cp -f "$TMP" "$DEST"
else
  python3 - <<PY > "$DEST"
import json,sys
try:
  j=json.load(open("$TMP"))
  sys.stdout.write(json.dumps(j,separators=(',',':')))
except Exception:
  # fallback: cat raw
  sys.stdout.write(open("$TMP").read())
PY
fi
cat "$DEST"
rm -f "$TMP" "$DEST"
