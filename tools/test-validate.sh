#!/usr/bin/env bash
# Unit tests for validate-content.sh, using throwaway fixtures.
set -uo pipefail
cd "$(dirname "$0")/.."
V=tools/validate-content.sh
TMP=.validate-fixtures
fails=0

setup() { rm -rf "$TMP"; mkdir -p "$TMP/_devlog" "$TMP/_articles" "$TMP/_projects"; }
teardown() { rm -rf "$TMP"; }

expect() { # expect <expected-exit> <description>
  local want="$1" desc="$2"
  ROOT="$TMP" bash "$V" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $desc"
  else echo "FAIL: $desc (expected exit $want, got $got)"; fails=$((fails+1)); fi
}

setup
printf -- '---\ntitle: "Ok"\ndate: 2026-03-12\n---\nbody\n' > "$TMP/_devlog/a.md"
printf -- '---\ntitle: "P"\ntagline: "t"\nkind: package\nstatus: active\nrepo: kovs705/P\n---\n' > "$TMP/_projects/p.md"
expect 0 "clean content passes"

printf -- '---\ntitle: "Quoted: colon is fine"\ndate: 2026-03-12\n---\nbody\n' > "$TMP/_devlog/g.md"
expect 0 "quoted title containing a colon is accepted"
rm "$TMP/_devlog/g.md"

printf -- "---\ntitle: \"Single quoted project\"\ndate: 2026-03-12\nproject: 'nosuchthing'\n---\n" > "$TMP/_devlog/h.md"
expect 1 "single-quoted dangling project reference fails"
rm "$TMP/_devlog/h.md"

printf -- '---\ntitle: "Mixed line"\ndate: 2026-03-12\n---\n<a href="{{ "/ok/" | relative_url }}">ok</a> <a href="/writing/">bad</a>\n' > "$TMP/_devlog/i.md"
expect 1 "broken absolute path on a line that also has a Liquid link fails"
rm "$TMP/_devlog/i.md"

# CRLF regression: without tr -d '\r' in frontmatter(), a valid CRLF file
# false-fails on missing title/date because "---\r" never matches "---".
printf -- '---\r\ntitle: "CRLF is fine"\r\ndate: 2026-03-12\r\n---\r\nbody\r\n' > "$TMP/_devlog/j.md"
expect 0 "CRLF line endings still parse as front matter"
rm "$TMP/_devlog/j.md"

# Duplicate-key regression: Psych uses last-key-wins, so a bad second title must be caught.
printf -- '---\ntitle: Fine\ntitle: Unquoted: colon\ndate: 2026-03-12\n---\n' > "$TMP/_devlog/k.md"
expect 1 "malformed duplicate title key is caught even when it is not first"
rm "$TMP/_devlog/k.md"

printf -- '---\ntitle: "No date"\n---\nbody\n' > "$TMP/_devlog/b.md"
expect 1 "devlog missing date fails"
rm "$TMP/_devlog/b.md"

printf -- '---\ntitle: "No summary"\ndate: 2026-03-10\n---\nbody\n' > "$TMP/_articles/c.md"
expect 1 "article missing summary fails"
rm "$TMP/_articles/c.md"

printf -- '---\ntitle: "Dangling"\ndate: 2026-03-12\nproject: nosuchthing\n---\n' > "$TMP/_devlog/d.md"
expect 1 "dangling project reference fails"
rm "$TMP/_devlog/d.md"

printf -- '---\ntitle: "Bad link"\ndate: 2026-03-12\n---\n<a href="/writing/">x</a>\n' > "$TMP/_devlog/e.md"
expect 1 "absolute internal path fails"
rm "$TMP/_devlog/e.md"

printf -- '---\ntitle: Unquoted: colon\ndate: 2026-03-12\n---\n' > "$TMP/_devlog/f.md"
expect 1 "unquoted colon in title fails"
rm "$TMP/_devlog/f.md"

teardown
echo "---"; [ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
