#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
PROM_BACKUP_DIR="wpconfig_promote_backups.${TS}"
mkdir -p "$PROM_BACKUP_DIR"

promoted=()
skipped=()
errors=()

shopt -s nullglob
for r in wp-config*.repair.*; do
  # compute the target original filename (strip final .repair.TIMESTAMP)
  target="${r%%.repair.*}"
  echo "Checking: $r  -> will target: $target"

  # lint the repair
  lint_out=$(php -l "$r" 2>&1) || true
  if echo "$lint_out" | grep -q "No syntax errors detected"; then
    echo "  LINT OK: promoting $r -> $target"
    # backup original (if it exists)
    if [ -f "$target" ]; then
      bk="${PROM_BACKUP_DIR}/$(basename "$target").promote_backup.${TS}"
      cp -p "$target" "$bk"
      echo "  backed up original -> $bk"
    fi
    # copy repair into place
    cp -pv "$r" "$target"
    promoted+=("$target")
  else
    echo "  LINT FAIL: skipping promotion for $r"
    echo "  php -l said:"
    echo "$lint_out"
    skipped+=("$r")
    # capture small context for debugging
    echo "  (context lines 1..220 of $r follow)"
    nl -ba "$r" | sed -n '1,220p'
    errors+=("$r")
  fi
done

# summary
echo
echo "=== PROMOTION SUMMARY ==="
echo "Promoted (${#promoted[@]}):"
for p in "${promoted[@]}"; do echo "  - $p"; done
echo
echo "Skipped (lint fail) (${#skipped[@]}):"
for s in "${skipped[@]}"; do echo "  - $s"; done
echo
if [ "${#errors[@]}" -gt 0 ]; then
  echo "NOTE: some repairs failed lint. Inspect the files listed under 'Skipped' and paste php -l output here if you want me to fix them."
fi

echo
echo "Backups of originals (if any) are in: $PROM_BACKUP_DIR"
