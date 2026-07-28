#!/usr/bin/env bash
# assert.sh <description> <pattern> <file>  — greps FILE for PATTERN, fails loudly.
set -uo pipefail
desc="$1"; pattern="$2"; file="$3"
if [ ! -f "$file" ]; then echo "FAIL: $desc — missing file $file"; exit 1; fi
if grep -qE -- "$pattern" "$file"; then echo "PASS: $desc"; else
  echo "FAIL: $desc — pattern not found: $pattern (in $file)"; exit 1; fi
