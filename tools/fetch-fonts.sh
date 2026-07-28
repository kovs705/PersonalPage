#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/fonts && tmp=$(mktemp -d)

echo "→ JetBrains Mono 2.304"
curl -fsSL -o "$tmp/jb.zip" \
  https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip
unzip -joq "$tmp/jb.zip" 'fonts/webfonts/JetBrainsMono-Regular.woff2' \
  'fonts/webfonts/JetBrainsMono-Medium.woff2' -d assets/fonts

echo "→ Source Serif 4.005"
curl -fsSL -o "$tmp/ss.zip" \
  https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_WOFF2.zip
unzip -joq "$tmp/ss.zip" '*SourceSerif4-Regular.otf.woff2' '*SourceSerif4-Semibold.otf.woff2' \
  '*SourceSerif4-It.otf.woff2' -d assets/fonts

rm -rf "$tmp"
echo
echo "Cabinet Grotesk must be downloaded by hand — Fontshare has no stable direct URL."
echo "  1. https://www.fontshare.com/fonts/cabinet-grotesk  → Download family"
echo "  2. Copy the 800 weight woff2 to assets/fonts/CabinetGrotesk-Extrabold.woff2"
echo "Until then display headings fall back to system-ui 800, which is a visual"
echo "downgrade only — nothing breaks and no other task is blocked."
ls -1 assets/fonts
