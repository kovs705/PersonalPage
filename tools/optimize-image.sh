#!/usr/bin/env bash
# optimize-image.sh file.png [more...]  — resize to <=1600px wide and encode webp <=250KB.
set -euo pipefail
command -v cwebp >/dev/null || { echo "cwebp not found: brew install webp"; exit 1; }
for src in "$@"; do
  [ -f "$src" ] || { echo "skip (not a file): $src"; continue; }
  base="${src%.*}"; out="${base}.webp"
  # mktemp -d + trap, not `tmp="$(mktemp -t oi).png"`: appending a suffix to a captured
  # mktemp path never renames the file mktemp actually created, so that first file
  # leaks silently on every run, success or failure. A scratch dir avoids that, and the
  # trap (not just a manual rm at the end) means a mid-loop failure under set -e still
  # cleans up — same lesson fetch-fonts.sh already learned about set -e vs cleanup.
  tmpdir="$(mktemp -d -t oi)"
  trap 'rm -rf "$tmpdir"' EXIT
  tmp="$tmpdir/src.png"
  sips -s format png "$src" --out "$tmp" >/dev/null
  w=$(sips -g pixelWidth "$tmp" | awk '/pixelWidth/{print $2}')
  [ "$w" -gt 1600 ] && sips -Z 1600 "$tmp" >/dev/null
  q=82
  while [ $q -ge 55 ]; do
    cwebp -quiet -q $q "$tmp" -o "$out"
    sz=$(wc -c < "$out")
    [ "$sz" -le 256000 ] && break
    q=$((q-8))
  done
  rm -rf "$tmpdir"
  trap - EXIT
  echo "$out — $(( $(wc -c < "$out") / 1024 ))KB (q=$q)"
  [ "$src" != "$out" ] && echo "  original kept; delete it before committing if unused"
done
