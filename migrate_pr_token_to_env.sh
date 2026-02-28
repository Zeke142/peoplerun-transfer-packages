#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
FOUND=0

FILES=(wp-config*.php*)

for F in "${FILES[@]}"; do
  [ -f "$F" ] || continue
  if grep -qE "define\\( *['\"]PR_GITHUB_TOKEN['\"]|commented-by-emergency-patch" "$F"; then
    FOUND=1
    OUT="${F}.repair.${TS}"
    echo "Processing: $F -> $OUT"
    cp -p "$F" "${F}.bak.${TS}"

    replaced=0
    # create/truncate OUT
    : > "$OUT"

    # read input file safely line-by-line
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$replaced" -eq 0 ] && [[ $line =~ define[[:space:]]*\(.*PR_GITHUB_TOKEN ]]; then
        # comment original and insert env guard
        echo "// $line  // commented-by-migration-${TS}" >> "$OUT"
        echo 'if (!defined("PR_GITHUB_TOKEN")) {' >> "$OUT"
        echo '  if (getenv("PR_GITHUB_TOKEN") !== false && getenv("PR_GITHUB_TOKEN") != "") {' >> "$OUT"
        echo '    define("PR_GITHUB_TOKEN", getenv("PR_GITHUB_TOKEN"));' >> "$OUT"
        echo '  }' >> "$OUT"
        echo '}' >> "$OUT"
        replaced=1
        continue
      fi

      # emergency commented single-line that contains both markers
      if [ "$replaced" -eq 0 ] && [[ "$line" == *commented-by-emergency-patch* ]] && [[ "$line" == *PR_GITHUB_TOKEN* ]]; then
        echo "/* PR_GITHUB_TOKEN literal removed by migration; use env PR_GITHUB_TOKEN */" >> "$OUT"
        echo 'if (!defined("PR_GITHUB_TOKEN") && getenv("PR_GITHUB_TOKEN") !== false) {' >> "$OUT"
        echo '  define("PR_GITHUB_TOKEN", getenv("PR_GITHUB_TOKEN"));' >> "$OUT"
        echo '}' >> "$OUT"
        replaced=1
        continue
      fi

      # otherwise emit original line
      echo "$line" >> "$OUT"
    done < "$F"

    # report lint result
    if php -l "$OUT" >/dev/null 2>&1; then
      echo "  LINT OK: $OUT"
    else
      echo "  LINT FAIL: $OUT"
      echo "  Inspect with: nl -ba \"$OUT\" | sed -n '1,220p'"
    fi
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "No files required migration (no PR_GITHUB_TOKEN or emergency markers found)."
fi
