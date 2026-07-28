#!/usr/bin/env bash
# Guards the invariants GitHub Pages will not catch for you.
# ROOT lets the test suite point this at fixtures.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="${ROOT:-.}"
errors=0
err() { echo "ERROR: $1"; errors=$((errors+1)); }

# Front matter of a file, i.e. everything between the first two --- lines.
frontmatter() { awk 'NR==1 && $0!="---"{exit} NR>1{if($0=="---")exit; print}' "$1"; }
has_key() { frontmatter "$1" | grep -qE "^$2:[[:space:]]*[^[:space:]]"; }

known_projects=""
if [ -d "$ROOT/_projects" ]; then
  for f in "$ROOT"/_projects/*.md; do
    [ -e "$f" ] || continue
    known_projects="$known_projects $(basename "$f" .md)"
  done
fi

check_common() {
  local f="$1"
  has_key "$f" title || err "$f: missing 'title'"
  has_key "$f" date  || err "$f: missing 'date'"
  # A title containing ':' must be quoted, or the YAML parser breaks the build.
  local t; t="$(frontmatter "$f" | grep -E '^title:' || true)"
  if echo "$t" | grep -qE '^title:[[:space:]]*[^"'"'"'].*:'; then
    err "$f: title contains ':' and is not quoted — this breaks the build"
  fi
  # project: must resolve to a real _projects/<slug>.md
  local p; p="$(frontmatter "$f" | sed -nE 's/^project:[[:space:]]*"?([A-Za-z0-9_-]+)"?.*/\1/p')"
  if [ -n "$p" ] && ! echo " $known_projects " | grep -q " $p "; then
    err "$f: project '$p' has no _projects/$p.md — the build log will silently be empty"
  fi
  # Absolute internal paths bypass baseurl and 404 in production.
  if grep -nE '(href|src)="/[a-zA-Z]' "$f" 2>/dev/null | grep -v '{{' | grep -q .; then
    err "$f: absolute internal path — use {{ '/x' | relative_url }}"
  fi
}

for f in "$ROOT"/_devlog/*.md; do [ -e "$f" ] || continue; check_common "$f"; done
for f in "$ROOT"/_articles/*.md; do
  [ -e "$f" ] || continue
  check_common "$f"
  has_key "$f" summary || err "$f: missing 'summary' (used for meta description and unfurl card)"
done
for f in "$ROOT"/_projects/*.md; do
  [ -e "$f" ] || continue
  for k in title tagline kind status; do has_key "$f" "$k" || err "$f: missing '$k'"; done
  if ! frontmatter "$f" | grep -qE '^status:[[:space:]]*coming-soon'; then
    has_key "$f" repo || err "$f: missing 'repo' (required unless status: coming-soon)"
  fi
done

# Absolute paths in templates are the top production risk.
for f in $(find "$ROOT/_layouts" "$ROOT/_includes" -name '*.html' 2>/dev/null); do
  if grep -nE '(href|src)="/[a-zA-Z]' "$f" | grep -vq 'relative_url'; then
    err "$f: absolute path in template — wrap in relative_url"
  fi
done

# Committed images over 250KB are permanent repo weight; git keeps deleted blobs forever.
if [ "$ROOT" = "." ] && git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r img; do
    [ -f "$img" ] || continue
    sz=$(wc -c < "$img")
    [ "$sz" -gt 256000 ] && err "$img is $((sz/1024))KB — resize to <=250KB (tools/optimize-image.sh)"
  done < <(git ls-files 'assets/img/*' 2>/dev/null)
fi

[ "$errors" -eq 0 ] && { echo "validate-content: OK"; exit 0; }
echo "validate-content: $errors error(s)"; exit 1
