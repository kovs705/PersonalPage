#!/usr/bin/env bash
# Production-parity Jekyll build. Host Ruby is too new for Jekyll 3.10, so this runs in Docker.
set -euo pipefail
cd "$(dirname "$0")/.."
docker run --rm \
  -v "$PWD":/srv -w /srv \
  -v personalpage-bundle:/usr/local/bundle \
  ruby:3.3-slim sh -c '
    if ! command -v git >/dev/null 2>&1; then
      apt-get update -qq && apt-get install -y -qq build-essential git >/dev/null
    fi
    bundle install --quiet
    bundle exec jekyll build "$@"
  ' -- "$@"
