#!/usr/bin/env bash
# new-devlog.sh "Title here" [project-slug]
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -ge 1 ] || { echo "usage: $0 \"Title\" [project-slug]"; exit 1; }
title="$1"; project="${2:-}"
slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
date=$(date +%Y-%m-%d)
file="_devlog/${date}-${slug}.md"
[ -e "$file" ] && { echo "exists: $file"; exit 1; }
{
  echo "---"
  echo "title: \"${title//\"/\\\"}\""
  echo "date: ${date}"
  [ -n "$project" ] && echo "project: ${project}"
  echo "tags: []"
  echo "---"
  echo
} > "$file"
mkdir -p "assets/img/devlog/${slug}"
echo "$file"
