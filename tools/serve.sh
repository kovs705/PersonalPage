#!/usr/bin/env bash
# Live preview at http://localhost:4000/PersonalPage/
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/_docker-preamble.sh
CMD="$DOCKER_PREAMBLE"'
bundle exec jekyll serve --host 0.0.0.0 --livereload
'
TTY=""; [ -t 0 ] && TTY="-it"
docker run --rm $TTY \
  -v "$PWD":/srv -w /srv -p 4000:4000 -p 35729:35729 \
  -v personalpage-bundle:/usr/local/bundle \
  ruby:3.3-slim sh -c "$CMD"
