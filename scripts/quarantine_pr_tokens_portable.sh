#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
LOG="$ROOT/pr_emitter_quarantine.log"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$(dirname "$LOG")"
echo "--- quarantine run $TS (user: $(whoami)) ---" >> "$LOG"

# Portable: write list of files to a temp file (avoids process-substitution / /dev/fd)
TMPFILE="$(mktemp /tmp/pr_files.XXXXXX)"
# find files that mention PR_GITHUB_TOKEN (case-sensitive), exclude .git and binary-ish patterns
grep -RIl --exclude-dir=.git --exclude="*.zip" "PR_GITHUB_TOKEN" . > "$TMPFILE" || true

if [ ! -s "$TMPFILE" ]; then
  echo "No files mention PR_GITHUB_TOKEN under $ROOT"
  rm -f "$TMPFILE"
  exit 0
fi

summary_total=0
summary_quarantined=0

# iterate lines of the temp file
while IFS= read -r file || [ -n "$file" ]; do
  # safeguard: skip if file doesn't exist or is a binary (grep found it, but guard)
  [ -f "$file" ] || { echo "WARN: skipped missing file $file"; continue; }
  summary_total=$((summary_total+1))

  # find define(...) lines with line numbers
  # use grep -n to capture lines like: 123:define( 'PR_GITHUB_TOKEN', '...' );
  grep -n -E "define\s*\(\s*['\"]PR_GITHUB_TOKEN['\"]" "$file" | while IFS= read -r ln || [ -n "$ln" ]; do
    lineno=${ln%%:*}
    line=$(sed -n "${lineno}p" "$file" || true)

    # skip if line already commented
    if echo "$line" | grep -qE '^[[:space:]]*(//|#)'; then
      echo "SKIP (already commented) -> $file:$lineno"
      continue
    fi

    # skip if it's not actually a define line (extra guard)
    if ! echo "$line" | grep -qE "define\s*\(\s*['\"]PR_GITHUB_TOKEN['\"]"; then
      echo "SKIP (not a define line) -> $file:$lineno"
      continue
    fi

    # backup file once per file
    bak="${file}.pre-quarantine-${TS}"
    if [ ! -f "$bak" ]; then
      cp -a "$file" "$bak"
      echo "BACKUP $file -> $bak"
    fi

    # try to extract a token (between single/double quotes)
    token="$(echo "$line" | sed -n "s/.*PR_GITHUB_TOKEN[^'\"\n]*['\"][[:space:]]*\([^'\"]\+\)['\"].*/\1/p" || true)"
    if [ -z "$token" ]; then
      # fallback: try to capture unquoted github_pat_... style tokens or constants
      token="$(echo "$line" | sed -n "s/.*\(github_pat_[A-Za-z0-9_\/+-]\+\).*/\1/p" || true)"
      token="$(echo "$token" | tr -d '[:space:];')"
    fi

    if [ -n "$token" ]; then
      sha10="$(printf '%s' "$token" | sha256sum | awk '{print substr($1,1,10)}')"
    else
      sha10="no-token-extracted"
    fi

    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $file:$lineno quarantined sha10=$sha10 backup=$bak" >> "$LOG"

    # replace only that exact line with a commented placeholder
    # this uses ed/sed -i line substitution; if sed -i isn't available in this environment,
    # the script will still try; most hosts provide it.
    sed -i "${lineno}s|.*|// quarantined PR_GITHUB_TOKEN removed (sha10:$sha10) - see $LOG|" "$file"

    echo "QUARANTINED -> $file:$lineno (sha10:$sha10)"
    summary_quarantined=$((summary_quarantined+1))
  done
done < "$TMPFILE"

rm -f "$TMPFILE"

echo
echo "SUMMARY: inspected $summary_total file(s); quarantined $summary_quarantined define(...) lines"
echo "Quarantine log: $LOG"
echo "Backups of modified files are created alongside the originals with suffix .pre-quarantine-$TS"
echo
echo "NEXT: rotate/revoke the affected tokens in GitHub immediately and verify mu-plugin loader is the only live source."
