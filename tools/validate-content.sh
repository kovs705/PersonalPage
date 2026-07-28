#!/usr/bin/env bash
# Guards the invariants GitHub Pages will not catch for you.
# ROOT lets the test suite point this at fixtures.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="${ROOT:-.}"
errors=0
err() { echo "ERROR: $1"; errors=$((errors+1)); }

# Front matter of a file, i.e. everything between the first two --- lines.
frontmatter() { tr -d '\r' < "$1" | awk 'NR==1 && $0!="---"{exit} NR>1{if($0=="---")exit; print}'; }
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
  # Check EVERY title: line, not just the first. Psych applies last-key-wins on duplicate
  # keys, so inspecting only the first can pass a file whose build-time value is malformed.
  # Note: an unterminated quote (title: "foo) is treated as quoted and accepted — that case
  # fails loudly at build time rather than silently, so it is out of scope for this guard.
  while IFS= read -r v; do
    case "$v" in
      \"*|\'*) ;;                                  # quoted — legal, whatever it contains
      *:*) err "$f: title contains ':' and is not quoted — this breaks the build" ;;
    esac
  done < <(frontmatter "$f" | sed -nE 's/^title:[[:space:]]*(.*)$/\1/p')
  # project: must resolve to a real _projects/<slug>.md
  local p; p="$(frontmatter "$f" | sed -nE "s/^project:[[:space:]]*['\"]?([A-Za-z0-9_-]+)['\"]?.*/\1/p")"
  if [ -n "$p" ] && ! echo " $known_projects " | grep -q " $p "; then
    err "$f: project '$p' has no _projects/$p.md — the build log will silently be empty"
  fi
  # Absolute internal paths bypass baseurl and 404 in production.
  # Strip Liquid expressions first so a correct link on the same line cannot mask a broken one.
  if sed 's/{{[^}]*}}//g' "$f" 2>/dev/null | grep -qE '(href|src)="/[a-zA-Z]'; then
    err "$f: absolute internal path — use {{ '/x' | relative_url }}"
  fi
}

for f in "$ROOT"/_devlog/*.md; do [ -e "$f" ] || continue; check_common "$f"; done
for f in "$ROOT"/_articles/*.md; do
  [ -e "$f" ] || continue
  check_common "$f"
  has_key "$f" description || err "$f: missing 'description' (jekyll-seo-tag reads THIS key for the meta description and unfurl card; a 'summary' key is invisible to it)"
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
  if sed 's/{{[^}]*}}//g' "$f" | grep -qE '(href|src)="/[a-zA-Z]'; then
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
