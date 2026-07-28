#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/fonts && tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "→ JetBrains Mono 2.304"
curl -fsSL --retry 2 --max-time 120 -o "$tmp/jb.zip" \
  https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip
# unzip exits 11 when a pattern matches nothing, and set -e turns that into a hard failure.
# That is load-bearing: it is what makes a future archive-layout change fail loudly instead of
# silently producing an incomplete font set. Do not wrap these calls in `if` without checking $?.
unzip -joq "$tmp/jb.zip" 'fonts/webfonts/JetBrainsMono-Regular.woff2' \
  'fonts/webfonts/JetBrainsMono-Medium.woff2' -d assets/fonts

echo "→ Source Serif 4.005"
curl -fsSL --retry 2 --max-time 120 -o "$tmp/ss.zip" \
  https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_WOFF2.zip
unzip -joq "$tmp/ss.zip" '*SourceSerif4-Regular.otf.woff2' '*SourceSerif4-Semibold.otf.woff2' \
  '*SourceSerif4-It.otf.woff2' -d assets/fonts

echo
echo "Cabinet Grotesk must be downloaded by hand — Fontshare has no stable direct URL."
echo "  1. https://www.fontshare.com/fonts/cabinet-grotesk  → Download family"
echo "  2. Copy the 800 weight woff2 to assets/fonts/CabinetGrotesk-Extrabold.woff2"
echo "Until then display headings fall back to system-ui 800, which is a visual"
echo "downgrade only — nothing breaks and no other task is blocked."
ls -1 assets/fonts

missing=""
for f in JetBrainsMono-Regular.woff2 JetBrainsMono-Medium.woff2 \
         SourceSerif4-Regular.otf.woff2 SourceSerif4-Semibold.otf.woff2 \
         SourceSerif4-It.otf.woff2; do
  [ -s "assets/fonts/$f" ] || missing="$missing $f"
done
if [ -n "$missing" ]; then
  echo
  echo "ERROR: font set is incomplete. Missing:$missing"
  echo "A missing font fails SILENTLY in the browser (it just falls back), so do not commit"
  echo "this state. Re-run this script once the network issue is resolved."
  exit 1
fi
echo
echo "OK: all 5 downloaded fonts present (Cabinet Grotesk is intentionally manual — see above)."
