#!/usr/bin/env bash
set -euo pipefail

OUTDIR="/home/customer/www/peoplerun.ai/public_html/wp-content/uploads/peoplerun/recover_reports"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$OUTDIR/pages_audit_summary.$TS.txt"
CSV_PATTERN="$OUTDIR/pages_http_audit.*.csv"

CSV="$(ls -1 $CSV_PATTERN 2>/dev/null | tail -n1 || true)"
if [ -z "$CSV" ]; then
  echo "$TS NO_CSV_FOUND" > "$OUT"
  exit 0
fi

# robust CSV parsing: extract 4th column, strip non-digits, then count
awk -F, 'NR>1{
  total++
  s = $4
  gsub(/^ *"|" *$/, "", s)     # strip surrounding quotes & leading/trailing spaces
  gsub(/[^0-9]/, "", s)        # keep only digits
  code = (s=="" ? "0" : s)     # empty -> 0
  code = code + 0              # numeric coercion
  if (code == 200) ok++
  else if (code >= 300 && code < 400) redir++
  else err++
}
END{
  printf("ts=%s csv=%s total=%d ok=%d redirects=%d errors=%d\n", ENVIRON["TS"], FILENAME, total, (ok+0), (redir+0), (err+0))
}' TS="$TS" "$CSV" > "$OUT"

# keep last 14 days of summaries
find "$OUTDIR" -name 'pages_audit_summary.*.txt' -mtime +14 -delete

# print path to summary and contents
printf "%s\n" "$OUT"
sed -n '1,200p' "$OUT"
