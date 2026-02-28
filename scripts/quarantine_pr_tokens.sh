#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
# place log in site root so no sudo required
LOG="$ROOT/pr_emitter_quarantine.log"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$(dirname "$LOG")"
echo "--- quarantine run $TS (user: $(whoami)) ---" >> "$LOG"

# 1) Build a list of files with PR_GITHUB_TOKEN (text files; include backups)
mapfile -t FILES < <(grep -RIl --exclude-dir=.git --exclude="*.zip" "PR_GITHUB_TOKEN" . || true)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No files mention PR_GITHUB_TOKEN under $ROOT"
  exit 0
fi

echo "Found ${#FILES[@]} file(s) mentioning PR_GITHUB_TOKEN. Checking each..."

# 2) Process each file
summary_total=0
summary_quarantined=0
for file in "${FILES[@]}"; do
  summary_total=$((summary_total+1))
  # find line numbers with define(...) occurrences (could be multiple)
  while IFS= read -r ln; do
    lineno=${ln%%:*}
    line=$(sed -n "${lineno}p" "$file" || true)
    # skip if line already starts with comment (// or #) after optional whitespace
    if echo "$line" | grep -qE '^[[:space:]]*(//|#)'; then
      echo "SKIP (already commented) -> $file:$lineno"
      continue
    fi

    # skip if the line does not contain define( ... PR_GITHUB_TOKEN ... )
    if ! echo "$line" | grep -qE "define\s*\(\s*['\"]PR_GITHUB_TOKEN['\"]"; then
      echo "SKIP (not a define line) -> $file:$lineno"
      continue
    fi

    # Make a safe backup once per file (timestamped)
    bak="${file}.pre-quarantine-${TS}"
    if [ ! -f "$bak" ]; then
      cp -a "$file" "$bak"
      echo "BACKUP $file -> $bak"
    fi

    # attempt to extract token between quotes; if not found, attempt looser extraction
    token="$(echo "$line" | sed -n "s/.*PR_GITHUB_TOKEN.*['\"][[:space:]]*\([^'\"]\+\)['\"].*/\1/p" || true)"
    # fallback: look for github_pat_... (unquoted constant style)
    if [ -z "$token" ]; then
      token="$(echo "$line" | sed -n "s/.*PR_GITHUB_TOKEN[^,]*,\s*\([^)]\+\)).*/\1/p" || true)"
      token="$(echo "$token" | tr -d '[:space:];')"
    fi

    # compute masked sha10 if token found; otherwise note 'no-token-extracted'
    if [ -n "$token" ]; then
      # compute SHA256 and mask — we never print the raw token
      sha10="$(printf '%s' "$token" | sha256sum | awk '{print substr($1,1,10)}')"
    else
      sha10="no-token-extracted"
    fi

    # record in the quarantine log (safe - no raw token)
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $file:$lineno quarantined sha10=$sha10 backup=$bak" >> "$LOG"

    # Replace the offending line with a safe commented placeholder containing the sha10
    # We replace only that line number to preserve file else.
    sed -i "${lineno}s|.*|// quarantined PR_GITHUB_TOKEN removed (sha10:$sha10) - see $LOG|" "$file"

    echo "QUARANTINED -> $file:$lineno (sha10:$sha10)"
    summary_quarantined=$((summary_quarantined+1))
  done < <(grep -n -E "define\s*\(\s*['\"]PR_GITHUB_TOKEN['\"]" "$file" || true)
done

echo
echo "SUMMARY: inspected $summary_total file(s); quarantined $summary_quarantined define(...) lines"
echo "Quarantine log: $LOG"
echo "Backups of modified files are created alongside the originals with suffix .pre-quarantine-$TS"
echo
echo "NEXT: rotate/revoke the affected tokens in GitHub immediately and verify mu-plugin loader is the only live source."
