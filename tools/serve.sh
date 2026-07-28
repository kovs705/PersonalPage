#!/usr/bin/env bash
# Live preview at http://localhost:4000/PersonalPage/
set -euo pipefail
cd "$(dirname "$0")/.."
docker run --rm -it \
  -v "$PWD":/srv -w /srv -p 4000:4000 \
  -v personalpage-bundle:/usr/local/bundle \
  ruby:3.3-slim sh -c '
    if ! command -v git >/dev/null 2>&1; then
      apt-get update -qq && apt-get install -y -qq build-essential git >/dev/null
    fi
    bundle install --quiet
    bundle exec jekyll serve --host 0.0.0.0 --livereload
  '
