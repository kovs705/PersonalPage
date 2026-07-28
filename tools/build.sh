#!/usr/bin/env bash
# Production-parity Jekyll build. Host Ruby is too new for Jekyll 3.10, so this runs in Docker.
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/_docker-preamble.sh
CMD="$DOCKER_PREAMBLE"'
bundle exec jekyll build "$@"
'
docker run --rm \
  -v "$PWD":/srv -w /srv \
  -v personalpage-bundle:/usr/local/bundle \
  ruby:3.3-slim sh -c "$CMD" -- "$@"
