#!/usr/bin/env bash
set -euo pipefail

# peoplerun-monitor.sh (installed in wp-content/pr-scripts)
WP_ROOT="/home/customer/www/peoplerun.ai/public_html"
PROOF="$WP_ROOT/wp-content/uploads/peoplerun/boot_proof.json"
EMISSIONS="$WP_ROOT/wp-content/uploads/peoplerun/emissions.log"
OUT="$WP_ROOT/wp-content/uploads/peoplerun/monitor_status.jsonl"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

ok=false
proof_exists=false
proof_time=""
ledger_sha=""

if [ -f "$PROOF" ]; then
  proof_exists=true
  if command -v jq >/dev/null 2>&1; then 
    ok=$(jq -r '.ok // "false"' "$PROOF")
    proof_time=$(jq -r '.time_utc // ""' "$PROOF")
    ledger_sha=$(jq -r '.ledger_sha1 // ""' "$PROOF")
  else
    ok=$(grep -Po '"ok"\s*:\s*\K(true|false)' "$PROOF" 2>/dev/null || echo "false")
    proof_time=$(grep -Po '"time_utc"\s*:\s*"\K[^"]+' "$PROOF" 2>/dev/null || echo "")
    ledger_sha=$(grep -Po '"ledger_sha1"\s*:\s*\K[^"]+' "$PROOF" 2>/dev/null || echo "")
  fi
fi

emissions_count=0
if [ -f "$EMISSIONS" ]; then
  emissions_count=$(wc -l < "$EMISSIONS" 2>/dev/null || echo 0)
fi

# Compose status line; fallback if jq missing
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ts "$TS" --argjson ok_val "$( [ "$ok" = "true" ] && echo true || echo false )" \
    --arg proof_time "$proof_time" --arg ledger_sha "$ledger_sha" --argjson emissions $emissions_count \
    '{ts: $ts, boot_ok: $ok_val, proof_time: $proof_time, ledger_sha: $ledger_sha, emissions_count: $emissions}' \
    >> "$OUT"
else
  # crude JSON fallback (safe for our small fields)
  printf '%s\n' "{\"ts\":\"$TS\",\"boot_ok\":$( [ \"$ok\" = \"true\" ] && echo true || echo false ),\"proof_time\":\"$proof_time\",\"ledger_sha\":\"$ledger_sha\",\"emissions_count\":$emissions_count}" >> "$OUT"
fi

# keep last 1000 lines
if [ -f "$OUT" ]; then
  tail -n 1000 "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT" || true
fi

if [ "$ok" = "true" ]; then
  exit 0
else
  exit 1
fi
