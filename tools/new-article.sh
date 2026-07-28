#!/usr/bin/env bash
# new-article.sh "Title here" [project-slug]
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -ge 1 ] || { echo "usage: $0 \"Title\" [project-slug]"; exit 1; }
title="$1"; project="${2:-}"
slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
date=$(date +%Y-%m-%d)
file="_articles/${slug}.md"
[ -e "$file" ] && { echo "exists: $file"; exit 1; }
{
  echo "---"
  echo "title: \"${title//\"/\\\"}\""
  echo "date: ${date}"
  echo "description: \"One sentence — jekyll-seo-tag reads this for the meta description and link preview.\""
  [ -n "$project" ] && echo "project: ${project}"
  echo "tags: []"
  echo "---"
  echo
} > "$file"
mkdir -p "assets/img/articles/${slug}"
echo "$file"
