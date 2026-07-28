#!/usr/bin/env sh
# Shared container setup, sourced by build.sh and serve.sh.
# Only installs build-essential/git when the bundle cache is cold — the
# --rm container never keeps apt state, but the named bundle volume persists
# across runs, so `bundle check` tells us whether we actually need them.
DOCKER_PREAMBLE='
if ! bundle check >/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y -qq build-essential git >/dev/null
fi
bundle install --quiet
'
