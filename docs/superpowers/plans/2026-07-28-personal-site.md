# Personal Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `kovs705.github.io/PersonalPage` — a Jekyll-on-GitHub-Pages personal site with articles, a devlog that attaches to project pages, ten curated projects, an about page, and a printable CV.

**Architecture:** GitHub Pages' built-in Jekyll (3.10 via the `github-pages` gem). Three output collections (`_articles`, `_devlog`, `_projects`) joined by a single `project:` front-matter key. All CSS and JS hand-written, no frameworks. Dark mono-led shell for scanning; bone-paper serif surfaces for reading. See the spec: [2026-07-27-personal-site-design.md](../specs/2026-07-27-personal-site-design.md).

**Tech Stack:** Jekyll 3.10, kramdown, Rouge, Liquid, `jekyll-seo-tag`, `jekyll-sitemap`. Docker (`ruby:3.3-slim`) for local builds. `sips` + `cwebp` for images. No npm, no CI workflow.

---

## How "TDD" works on a static site

There is no unit-test framework here, so the discipline is adapted rather than dropped. Every task follows the same loop:

1. **Write the assertion first** — a `grep` against built output in `_site/`, or a fixture that `tools/validate-content.sh` must reject.
2. **Run it and watch it fail** — this proves the assertion is real and not vacuously passing.
3. **Implement.**
4. **Run it and watch it pass.**
5. **Commit.**

`tools/validate-content.sh` (Task 2) is tested with genuine fixtures and is the one component with real unit tests.

**Non-negotiable rule throughout:** every internal path goes through `{{ '/path' | relative_url }}`. A bare `href="/writing/"` works nowhere, because the site is served from the `/PersonalPage` subpath. Task 2 builds the guard that catches this.

**Every top-level page needs an explicit `permalink:`.** Jekyll's pretty collection permalinks apply
only to collections. A plain page at `projects.md` with no `permalink` builds to `_site/projects.html`,
**not** `_site/projects/index.html` — so `/projects/` 404s while `/projects.html` works. This bit
Task 7 during implementation. Affected pages and their required values:

| file | `permalink:` |
|---|---|
| `projects.md` | `/projects/` |
| `writing.html` | `/writing/` |
| `devlog.html` | `/devlog/` |
| `tags.html` | `/tags/` |
| `about.md` | `/about/` |
| `cv.md` | `/cv/` |

`index.html`, `404.html` (`permalink: /404.html`) and `feed.xml` (`permalink: /feed.xml`) are already
correct. The failure is at least loud rather than silent: each task's assertion targets
`_site/<name>/index.html`, so a forgotten `permalink` fails the assertion with a missing file.

---

## Verified environment facts

These were checked on this machine before writing the plan. Do not re-litigate them.

| Fact | Detail |
|---|---|
| Host Ruby is unusable for this | System Ruby 2.6.10; Homebrew Ruby is 4.0.5. `github-pages` pins Jekyll 3.10, which will not build cleanly on Ruby 4. **Use Docker.** |
| Docker works | `ruby:3.3-slim` + `bundle install` + `jekyll build` succeeds. Bundle is cached in a named volume so only the first run is slow (~2 min). |
| `repository:` is mandatory | Without it the build **fails hard**: `No repo name found`. The `jekyll-github-metadata` plugin bundled into `github-pages` requires it. This cost a build failure during verification — it is already in Task 1. |
| Rouge, collections, `relative_url`, `seo` all verified | Custom collection permalinks emit `/writing/<slug>/index.html`; `relative_url` emits `/PersonalPage/...`; canonical URLs resolve to `https://kovs705.github.io/PersonalPage/`. |
| Harmless build artifact | `_site/assets/css/style.css` appears from the bundled `minima` gem. It is unreferenced and ignorable. Do not spend time removing it. |
| Image tools | `cwebp` 1.6.0 and `sips` present. **No ImageMagick** — `optimize-image.sh` uses `sips` to resize and `cwebp` to encode. |
| Font sources | JetBrains Mono `v2.304` zip URL verified 200. Source Serif needs asset `source-serif-4.005_WOFF2.zip` (**not** `source-serif-4.005R.zip`, which 404s). Cabinet Grotesk has no stable direct URL — manual, with a graceful fallback. |

---

## File Structure

| Path | Responsibility |
|---|---|
| `_config.yml` | Site config, collections, `baseurl`, `repository` |
| `Gemfile` | Pins `github-pages` for local parity |
| `tools/build.sh`, `tools/serve.sh` | Docker wrappers — the only build commands anyone runs |
| `tools/validate-content.sh` | Front-matter, dangling-ref, absolute-path, and image-size guard |
| `tools/new-article.sh`, `tools/new-devlog.sh` | Scaffold content with front matter pre-filled |
| `tools/optimize-image.sh` | Resize + webp encode |
| `_layouts/base.html` | HTML shell, head, header, footer |
| `_layouts/home.html` | Homepage blocks |
| `_layouts/page.html` | Generic dark shell page (indexes, tags, 404) |
| `_layouts/article.html` | Bone-paper reading surface; `.is-entry` modifier for devlog |
| `_layouts/project.html` | Project detail + attached build log |
| `_layouts/cv.html` | CV, print-targeted |
| `_includes/head.html` | Meta, fonts, SEO, analytics |
| `_includes/header.html` | Mono nav + clack toggle |
| `_includes/footer.html` | Contact links |
| `_includes/entry-row.html` | One writing row — used by home, `/writing/`, `/devlog/`, project pages |
| `_includes/package-row.html` | One project row with copy button |
| `_includes/copy-button.html` | Shared copy control; `copy.js` depends on its data-attribute contract |
| `_includes/figure.html`, `note.html`, `video.html` | Rich content in Markdown |
| `assets/css/site.css` | Tokens, reset, shell, rows, controls |
| `assets/css/article.css` | Bone paper reading surface |
| `assets/css/rouge.css` | Syntax highlighting |
| `assets/css/print.css` | CV print |
| `assets/js/clack.js`, `copy.js`, `tilt.js`, `filter.js` | Four independent enhancements |
| `_data/tools.yml`, `_data/external_writing.yml` | Gists and externally-published writing |
| `feed.xml` | Hand-written Atom merging both collections |

**Spec refinement, decided during planning.** Spec §3.9 proposed merging `_data/external_writing.yml` into the sorted writing list. Do **not** do this: Liquid's `sort` filter would compare a YAML `Date` from the data file against a Jekyll `Time` from a document, which raises at build time. External entries instead render as their own labelled "Published elsewhere" block. This is also better for the reader — it signals up front that the piece lives on dev.to.

---

## Task 1: Build harness and configuration

**Files:**
- Create: `Gemfile`, `_config.yml`, `tools/build.sh`, `tools/serve.sh`, `index.md`
- Modify: `.gitignore`

- [ ] **Step 1: Write the assertion first**

Create `tools/assert.sh`:

```bash
#!/usr/bin/env bash
# assert.sh <description> <pattern> <file>  — greps FILE for PATTERN, fails loudly.
set -uo pipefail
desc="$1"; pattern="$2"; file="$3"
if [ ! -f "$file" ]; then echo "FAIL: $desc — missing file $file"; exit 1; fi
if grep -qE -- "$pattern" "$file"; then echo "PASS: $desc"; else
  echo "FAIL: $desc — pattern not found: $pattern (in $file)"; exit 1; fi
```

```bash
chmod +x tools/assert.sh
```

- [ ] **Step 2: Run it to verify it fails**

```bash
tools/assert.sh "site builds with correct canonical" 'PersonalPage/' _site/index.html
```

Expected: `FAIL: ... missing file _site/index.html`

- [ ] **Step 3: Implement the harness**

`Gemfile`:

```ruby
source "https://rubygems.org"
gem "github-pages", group: :jekyll_plugins
```

`_config.yml`:

```yaml
title: "Eugene Rozhkov"
tagline: "iOS developer — Apple platforms, SwiftUI, Kotlin Multiplatform"
description: "iOS developer shipping in healthcare and logistics. Swift packages, articles, and a development log."
author: "Eugene Rozhkov"
email: "EuKovs@gmail.com"

url: "https://kovs705.github.io"
baseurl: "/PersonalPage"
repository: kovs705/PersonalPage   # REQUIRED — build fails without it
lang: en

social:
  github: kovs705
  telegram: kovs705
  linkedin: kovs705

goatcounter: ""   # set to your GoatCounter code in Task 17; empty disables the script

collections:
  articles:
    output: true
    permalink: /writing/:name/
  devlog:
    output: true
    permalink: /devlog/:slug/   # :slug strips the date prefix; :name does NOT
  projects:
    output: true
    permalink: /projects/:name/

plugins:
  - jekyll-seo-tag
  - jekyll-sitemap

markdown: kramdown
kramdown:
  input: GFM
  syntax_highlighter: rouge
  syntax_highlighter_opts:
    block:
      line_numbers: false

sass:
  style: compressed

defaults:
  - scope: { path: "", type: "articles" }
    values: { layout: "article", surface: "bone", section: "writing" }
  - scope: { path: "", type: "devlog" }
    values: { layout: "article", surface: "bone", section: "writing" }
  - scope: { path: "", type: "projects" }
    values: { layout: "project", section: "projects" }

exclude:
  - Gemfile
  - Gemfile.lock
  - tools
  - docs
  - README.md
  - .superpowers
```

`tools/build.sh`:

```bash
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
```

`tools/serve.sh`:

```bash
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
```

```bash
chmod +x tools/build.sh tools/serve.sh
```

`index.md` (temporary placeholder, replaced in Task 8):

```markdown
---
layout: null
title: Home
---
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{ site.title }}</title></head>
<body><a href="{{ '/writing/' | relative_url }}">writing</a></body></html>
```

Append to `.gitignore`:

```
_site/
.jekyll-cache/
.jekyll-metadata
```

- [ ] **Step 4: Run the build and the assertion to verify they pass**

```bash
tools/build.sh && tools/assert.sh "baseurl applied to internal links" '/PersonalPage/writing/' _site/index.html
```

Expected: build completes (`done in N seconds`), then `PASS: baseurl applied to internal links`.

First run installs ~100 gems and takes about two minutes. Later runs are ~2 seconds.

If the build reports `No repo name found`, `repository:` is missing from `_config.yml`.

**Expected warnings until Task 9:** `defaults` above points at the `article` and `project`
layouts, which don't exist yet. Jekyll 3 logs `Build Warning: Layout 'project' requested ... does
not exist` and renders the content without a layout. This is a warning, not an error — the build
still succeeds. The warnings disappear as Tasks 7 and 9 create the layouts. Declaring `defaults`
here rather than later means no task has to retro-edit `_config.yml`.

- [ ] **Step 5: Commit**

```bash
git add Gemfile Gemfile.lock _config.yml index.md tools/ .gitignore
git commit -m "build: Jekyll harness with Docker parity build"
```

---

## Task 2: Content validation guard

This is the one component with real unit tests. It is also the guard against the highest-risk failure in the spec (absolute paths breaking under `baseurl`).

**Files:**
- Create: `tools/validate-content.sh`, `tools/test-validate.sh`

- [ ] **Step 1: Write the failing test**

`tools/test-validate.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for validate-content.sh, using throwaway fixtures.
set -uo pipefail
cd "$(dirname "$0")/.."
V=tools/validate-content.sh
TMP=.validate-fixtures
fails=0

setup() { rm -rf "$TMP"; mkdir -p "$TMP/_devlog" "$TMP/_articles" "$TMP/_projects"; }
teardown() { rm -rf "$TMP"; }

expect() { # expect <expected-exit> <description>
  local want="$1" desc="$2"
  ROOT="$TMP" bash "$V" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $desc"
  else echo "FAIL: $desc (expected exit $want, got $got)"; fails=$((fails+1)); fi
}

setup
printf -- '---\ntitle: "Ok"\ndate: 2026-03-12\n---\nbody\n' > "$TMP/_devlog/a.md"
printf -- '---\ntitle: "P"\ntagline: "t"\nkind: package\nstatus: active\nrepo: kovs705/P\n---\n' > "$TMP/_projects/p.md"
expect 0 "clean content passes"

# Accept-path regression tests. Reject-path-only coverage is how the quoted-title
# false positive shipped green the first time.
printf -- '---\ntitle: "Quoted: colon is fine"\ndate: 2026-03-12\n---\nbody\n' > "$TMP/_devlog/g.md"
expect 0 "quoted title containing a colon is accepted"
rm "$TMP/_devlog/g.md"

printf -- "---\ntitle: \"Single quoted project\"\ndate: 2026-03-12\nproject: 'nosuchthing'\n---\n" > "$TMP/_devlog/h.md"
expect 1 "single-quoted dangling project reference fails"
rm "$TMP/_devlog/h.md"

printf -- '---\ntitle: "Mixed line"\ndate: 2026-03-12\n---\n<a href="{{ "/ok/" | relative_url }}">ok</a> <a href="/writing/">bad</a>\n' > "$TMP/_devlog/i.md"
expect 1 "broken absolute path on a line that also has a Liquid link fails"
rm "$TMP/_devlog/i.md"

# CRLF regression: without tr -d '\r' in frontmatter(), a valid CRLF file
# false-fails on missing title/date because "---\r" never matches "---".
printf -- '---\r\ntitle: "CRLF is fine"\r\ndate: 2026-03-12\r\n---\r\nbody\r\n' > "$TMP/_devlog/j.md"
expect 0 "CRLF line endings still parse as front matter"
rm "$TMP/_devlog/j.md"

# Duplicate-key regression: Psych uses last-key-wins, so a bad second title must be caught.
printf -- '---\ntitle: Fine\ntitle: Unquoted: colon\ndate: 2026-03-12\n---\n' > "$TMP/_devlog/k.md"
expect 1 "malformed duplicate title key is caught even when it is not first"
rm "$TMP/_devlog/k.md"

printf -- '---\ntitle: "No date"\n---\nbody\n' > "$TMP/_devlog/b.md"
expect 1 "devlog missing date fails"
rm "$TMP/_devlog/b.md"

printf -- '---\ntitle: "No description"\ndate: 2026-03-10\n---\nbody\n' > "$TMP/_articles/c.md"
expect 1 "article missing description fails"
rm "$TMP/_articles/c.md"

printf -- '---\ntitle: "Dangling"\ndate: 2026-03-12\nproject: nosuchthing\n---\n' > "$TMP/_devlog/d.md"
expect 1 "dangling project reference fails"
rm "$TMP/_devlog/d.md"

printf -- '---\ntitle: "Bad link"\ndate: 2026-03-12\n---\n<a href="/writing/">x</a>\n' > "$TMP/_devlog/e.md"
expect 1 "absolute internal path fails"
rm "$TMP/_devlog/e.md"

printf -- '---\ntitle: Unquoted: colon\ndate: 2026-03-12\n---\n' > "$TMP/_devlog/f.md"
expect 1 "unquoted colon in title fails"
rm "$TMP/_devlog/f.md"

teardown
echo "---"; [ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
```

```bash
chmod +x tools/test-validate.sh
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
tools/test-validate.sh
```

Expected: every case reports FAIL, because `tools/validate-content.sh` does not exist yet.

- [ ] **Step 3: Write the implementation**

`tools/validate-content.sh`:

```bash
#!/usr/bin/env bash
# Guards the invariants GitHub Pages will not catch for you.
# ROOT lets the test suite point this at fixtures.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="${ROOT:-.}"
errors=0
err() { echo "ERROR: $1"; errors=$((errors+1)); }

# Front matter of a file, i.e. everything between the first two --- lines.
frontmatter() { tr -d '\r' < "$1" | awk 'NR==1 && $0!="---"{exit} NR>1{if($0=="---")exit; print}'; }
has_key() { frontmatter "$1" | grep -qE "^$2:[[:space:]]*[^[:space:]]"; }

known_projects=""
if [ -d "$ROOT/_projects" ]; then
  for f in "$ROOT"/_projects/*.md; do
    [ -e "$f" ] || continue
    known_projects="$known_projects $(basename "$f" .md)"
  done
fi

check_common() {
  local f="$1"
  has_key "$f" title || err "$f: missing 'title'"
  has_key "$f" date  || err "$f: missing 'date'"
  # A title containing ':' must be quoted, or the YAML parser breaks the build.
  # Extract the value, then test it. A regex over the whole line cannot tell a quoted
  # colon from an unquoted one, and gets this backwards.
  # Check EVERY title: line, not just the first. Psych applies last-key-wins on duplicate
  # keys, so inspecting only the first can pass a file whose build-time value is malformed.
  # Note: an unterminated quote (title: "foo) is treated as quoted and accepted — that case
  # fails loudly at build time rather than silently, so it is out of scope for this guard.
  while IFS= read -r v; do
    case "$v" in
      \"*|\'*) ;;                                  # quoted — legal, whatever it contains
      *:*) err "$f: title contains ':' and is not quoted — this breaks the build" ;;
    esac
  done < <(frontmatter "$f" | sed -nE 's/^title:[[:space:]]*(.*)$/\1/p')
  # project: must resolve to a real _projects/<slug>.md
  local p; p="$(frontmatter "$f" | sed -nE "s/^project:[[:space:]]*['\"]?([A-Za-z0-9_-]+)['\"]?.*/\1/p")"
  if [ -n "$p" ] && ! echo " $known_projects " | grep -q " $p "; then
    err "$f: project '$p' has no _projects/$p.md — the build log will silently be empty"
  fi
  # Absolute internal paths bypass baseurl and 404 in production.
  # Strip Liquid expressions first, so a correct link cannot mask a broken one on the same line.
  if sed 's/{{[^}]*}}//g' "$f" 2>/dev/null | grep -qE '(href|src)="/[a-zA-Z]'; then
    err "$f: absolute internal path — use {{ '/x' | relative_url }}"
  fi
}

for f in "$ROOT"/_devlog/*.md; do [ -e "$f" ] || continue; check_common "$f"; done
for f in "$ROOT"/_articles/*.md; do
  [ -e "$f" ] || continue
  check_common "$f"
  has_key "$f" description || err "$f: missing 'description' (jekyll-seo-tag reads THIS key for the meta description and unfurl card; a 'summary' key is invisible to it)"
done
for f in "$ROOT"/_projects/*.md; do
  [ -e "$f" ] || continue
  for k in title tagline kind status; do has_key "$f" "$k" || err "$f: missing '$k'"; done
  if ! frontmatter "$f" | grep -qE '^status:[[:space:]]*coming-soon'; then
    has_key "$f" repo || err "$f: missing 'repo' (required unless status: coming-soon)"
  fi
done

# Absolute paths in templates are the top production risk.
for f in $(find "$ROOT/_layouts" "$ROOT/_includes" -name '*.html' 2>/dev/null); do
  if sed 's/{{[^}]*}}//g' "$f" | grep -qE '(href|src)="/[a-zA-Z]'; then
    err "$f: absolute path in template — wrap in relative_url"
  fi
done

# Committed images over 250KB are permanent repo weight; git keeps deleted blobs forever.
if [ "$ROOT" = "." ] && git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r img; do
    [ -f "$img" ] || continue
    sz=$(wc -c < "$img")
    [ "$sz" -gt 256000 ] && err "$img is $((sz/1024))KB — resize to <=250KB (tools/optimize-image.sh)"
  done < <(git ls-files 'assets/img/*' 2>/dev/null)
fi

[ "$errors" -eq 0 ] && { echo "validate-content: OK"; exit 0; }
echo "validate-content: $errors error(s)"; exit 1
```

```bash
chmod +x tools/validate-content.sh
```

**Three correctness notes, each of which was a real bug caught in review:**

1. **No regex lookahead.** POSIX ERE has no `(?!`. The absolute-path scan uses a literal
   character class, not a negative lookahead.
2. **Strip Liquid before scanning, never filter by line.** An earlier version piped through
   `grep -v '{{'`, which drops the whole line — so a line holding both a correct
   `{{ '/x' | relative_url }}` link and a broken `href="/writing/"` escaped detection entirely.
   Header and footer partials routinely put several links on one line, so that false negative was
   live. `sed 's/{{[^}]*}}//g'` removes the templated parts first, then the scan sees only raw HTML.
3. **Test the title value, not the title line.** A regex like `^title:[[:space:]]*[^"'].*:` cannot
   distinguish a quoted colon from an unquoted one — `[^"']` matches the space after `title:` and
   then finds the colon inside the quotes, so it rejects the perfectly legal
   `title: "Hello: world"`. Extract the value and `case` on it instead.

- [ ] **Step 4: Run tests to verify they pass**

```bash
tools/test-validate.sh && tools/validate-content.sh
```

Expected: `all passed`, then `validate-content: OK`.

- [ ] **Step 5: Commit**

```bash
git add tools/validate-content.sh tools/test-validate.sh
git commit -m "test: content validation guard with fixtures"
```

---

## Task 3: Self-hosted fonts

**Files:**
- Create: `assets/fonts/*.woff2`, `assets/css/fonts.css`
- Create: `tools/fetch-fonts.sh`

- [ ] **Step 1: Write the assertion first**

```bash
tools/assert.sh "JetBrains Mono present" 'JetBrainsMono' assets/css/fonts.css
```

Expected: FAIL — missing file.

- [ ] **Step 2: Write the fetch script**

`tools/fetch-fonts.sh`:

```bash
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

# A missing font degrades SILENTLY in the browser, and there is no CI to catch it — so the
# script must refuse to end quietly on a half-completed download. -s also catches a
# zero-byte file, which is what a truncated write leaves behind.
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
```

```bash
chmod +x tools/fetch-fonts.sh && tools/fetch-fonts.sh
```

- [ ] **Step 3: Write `assets/css/fonts.css`**

```css
/* Self-hosted. No CDN request, no third-party dependency. */
@font-face{font-family:"Cabinet Grotesk";src:url("../fonts/CabinetGrotesk-Extrabold.woff2") format("woff2");
  font-weight:800;font-style:normal;font-display:swap}
@font-face{font-family:"JetBrains Mono";src:url("../fonts/JetBrainsMono-Regular.woff2") format("woff2");
  font-weight:400;font-style:normal;font-display:swap}
@font-face{font-family:"JetBrains Mono";src:url("../fonts/JetBrainsMono-Medium.woff2") format("woff2");
  font-weight:500;font-style:normal;font-display:swap}
@font-face{font-family:"Source Serif 4";src:url("../fonts/SourceSerif4-Regular.otf.woff2") format("woff2");
  font-weight:400;font-style:normal;font-display:swap}
@font-face{font-family:"Source Serif 4";src:url("../fonts/SourceSerif4-Semibold.otf.woff2") format("woff2");
  font-weight:600;font-style:normal;font-display:swap}
@font-face{font-family:"Source Serif 4";src:url("../fonts/SourceSerif4-It.otf.woff2") format("woff2");
  font-weight:400;font-style:italic;font-display:swap}
```

- [ ] **Step 4: Run the assertion to verify it passes**

```bash
tools/assert.sh "JetBrains Mono present" 'JetBrainsMono' assets/css/fonts.css
ls -1 assets/fonts/*.woff2 | wc -l
```

Expected: `PASS`, and at least 5 files.

- [ ] **Step 5: Commit**

```bash
git add assets/fonts assets/css/fonts.css tools/fetch-fonts.sh
git commit -m "feat: self-hosted fonts"
```

---

## Task 4: Design tokens, reset, and the tactility layer

**Files:**
- Create: `assets/css/site.css`

- [ ] **Step 1: Write the assertion first**

```bash
tools/assert.sh "grain filter inlined" 'feTurbulence' assets/css/site.css
```

Expected: FAIL — missing file.

- [ ] **Step 2: Write `assets/css/site.css`**

```css
/* fonts.css is linked directly in _includes/head.html, not @imported here — an @import
   serialises the font CSS behind this file on the critical path. */

:root{
  /* shell — dark, dense, mono-led */
  --ink:#121310; --ink-2:#1B1D16; --line:#26281F;
  --paper:#F3F0E7; --dim:#8E9184; --lime:#C9F227; --meta:#7E8175; --line-2:#33362B;
  /* article — bone paper */
  --bone:#F2EFE6; --bone-2:#DBD6C7; --article-ink:#15140F; --tomato:#E8422C;
  /* --tomato measures 3.48:1 on bone: fine for borders, rules and focus rings (3:1 threshold)
     but it FAILS the 4.5:1 text threshold. Small text on bone uses --tomato-ink (4.76:1),
     same hue, darker value. Do not use --tomato for text under 18px. */
  --tomato-ink:#C13725;

  --ease:cubic-bezier(.2,.8,.3,1);
  --t-press:80ms; --t-hover:180ms;
  --r-sm:3px; --r-md:7px; --r-lg:12px;
  --s1:4px; --s2:8px; --s3:12px; --s4:16px; --s5:24px; --s6:32px; --s7:48px; --s8:72px;

  --mono:"JetBrains Mono",ui-monospace,"SF Mono",Menlo,monospace;
  --display:"Cabinet Grotesk",system-ui,-apple-system,sans-serif;
  --serif:"Source Serif 4",Georgia,serif;
}

*,*::before,*::after{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--ink);color:var(--paper);
  font:400 15px/1.6 var(--mono);font-feature-settings:"ss02";}
img,video{max-width:100%;height:auto;display:block}
a{color:inherit;text-decoration:none}
h1,h2,h3{margin:0;font-family:var(--display);font-weight:800;letter-spacing:-.03em;line-height:1}

/* Grain. One inline SVG, no image file. */
.grain{position:relative}
.grain::before{content:"";position:absolute;inset:0;pointer-events:none;z-index:0;
  opacity:.06;mix-blend-mode:screen;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3'/%3E%3C/filter%3E%3Crect width='120' height='120' filter='url(%23n)'/%3E%3C/svg%3E")}
.grain>*{position:relative;z-index:1}

.wrap{max-width:960px;margin:0 auto;padding:0 var(--s5)}

/* Header */
.site-header{border-bottom:1px solid var(--line)}
.site-header .wrap{display:flex;justify-content:space-between;align-items:center;
  gap:var(--s4);padding-top:var(--s4);padding-bottom:var(--s4);flex-wrap:wrap}
.brand{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--dim)}
.brand b{color:var(--paper);font-weight:500}
.site-nav{display:flex;flex-wrap:wrap;gap:var(--s4);font-size:12px;letter-spacing:.08em;
  text-transform:uppercase;color:var(--dim)}
.site-nav a[aria-current="page"]{color:var(--lime)}
.site-nav a:hover{color:var(--paper)}

/* Clack toggle — a control, a joke, and a demo of Clackable. */
.clack{display:inline-flex;align-items:center;gap:var(--s2);border:1px solid var(--line);
  border-radius:999px;padding:3px 4px 3px 10px;font:400 10px/1 var(--mono);
  letter-spacing:.07em;text-transform:uppercase;color:var(--dim);background:none;cursor:pointer}
.clack .sw{width:26px;height:15px;border-radius:999px;background:var(--line);position:relative;
  transition:background var(--t-hover) var(--ease)}
.clack .sw::after{content:"";position:absolute;top:2px;left:2px;width:11px;height:11px;
  border-radius:50%;background:var(--paper);transition:transform var(--t-hover) var(--ease)}
/* .clack-on on <html> is a pre-paint stamp from the inline anti-flash guard in head.html —
   it renders the switch correctly before clack.js has run and set aria-pressed itself. */
.clack[aria-pressed="true"] .sw, .clack-on .clack .sw{background:var(--lime)}
.clack[aria-pressed="true"] .sw::after, .clack-on .clack .sw::after{transform:translateX(11px);background:var(--ink)}

/* Section labels */
.lbl{display:flex;justify-content:space-between;gap:var(--s4);
  font:500 10px/1 var(--mono);letter-spacing:.15em;text-transform:uppercase;
  color:var(--meta);border-top:1px solid var(--line);padding-top:var(--s3);margin:var(--s7) 0 0}
/* The first span of a .lbl is an <h2> for screen-reader navigation (see Task 8 fix), but must
   stay pixel-identical to a plain span — override the global h1,h2,h3 display-font rule. */
.lbl h2{font:inherit;font-size:inherit;font-weight:inherit;letter-spacing:inherit;
  color:inherit;margin:0}

/* Rows — the primary unit of the whole site */
.row{display:grid;grid-template-columns:1fr auto;gap:var(--s4);align-items:baseline;
  padding:var(--s3) 0;border-bottom:1px solid var(--ink-2)}
.row-title{font-size:14.5px;font-weight:500}
.row-title em{font-style:normal;font-weight:400;color:var(--meta)}
.row-meta{font-size:11px;color:var(--meta);letter-spacing:.04em;white-space:nowrap}
a.row:hover .row-title{color:var(--lime)}
.row-title a:hover,.row-title a:focus-visible{color:var(--lime)}
.row-date{font-size:11px;color:var(--meta)}

/* Chunky physical controls: hard offset shadow, press drops 1px. */
.btn{display:inline-flex;align-items:center;gap:var(--s2);font:500 12.5px/1 var(--mono);
  padding:9px 14px;border-radius:var(--r-md);cursor:pointer;
  background:var(--lime);color:var(--ink);border:1.5px solid var(--ink);
  box-shadow:3px 3px 0 rgba(201,242,39,.28);
  transition:transform var(--t-press) var(--ease),box-shadow var(--t-press) var(--ease)}
.btn.ghost{background:transparent;color:var(--paper);border-color:var(--line-2);
  box-shadow:3px 3px 0 rgba(255,255,255,.07)}
.btn:active{transform:translateY(1px);box-shadow:1px 1px 0 rgba(201,242,39,.28)}
.btn.ghost:active{box-shadow:1px 1px 0 rgba(255,255,255,.07)}

.copy{font:400 11px/1 var(--mono);color:var(--dim);border:1px dashed var(--line-2);
  border-radius:var(--r-md);padding:8px 10px;display:flex;justify-content:space-between;
  gap:var(--s4);width:100%;min-width:0;background:none;cursor:pointer;text-align:left;
  transition:transform var(--t-press) var(--ease)}
.copy:active{transform:translateY(1px)}
.copy b{color:var(--lime);font-weight:500}
.copy>span{min-width:0;overflow-wrap:anywhere}

/* Inline copy control for list rows — keeps a row to one line (unlike .copy, which is a
   full-width block used only on project detail pages). Always visible: a hover-only
   control is unreachable for touch and confusing for keyboard users. */
.copy-inline{font:inherit;font-size:inherit;color:var(--lime);background:none;border:0;
  padding:0;margin:0;cursor:pointer;transition:transform var(--t-press) var(--ease)}
.copy-inline:active{transform:translateY(1px)}

/* Focus must always be obvious in a dense keyboard-navigable list. */
:focus-visible{outline:2px solid var(--lime);outline-offset:2px}

/* Hero. Knockout is shell-only — lime never appears on bone (contrast). */
.hero{padding:var(--s8) 0 var(--s7)}
/* Index/section pages: shorter tail than the homepage hero. A class, not an inline style,
   so the project layout can reuse it instead of copying a declaration. */
.hero-tight{padding-bottom:var(--s5)}
.hero h1{font-size:clamp(30px,6vw,50px);line-height:.99;max-width:16em}
.hero h1 .knock{display:inline-block;color:var(--ink);background:var(--lime);
  padding:0 var(--s2);border-radius:var(--r-sm);transform:rotate(-2.2deg)}
.hero .dek{color:var(--dim);font-size:14.5px;max-width:34em;margin:var(--s4) 0 0}
.hero-cta{display:flex;gap:var(--s3);flex-wrap:wrap;margin-top:var(--s5)}

.chips{display:flex;gap:var(--s2);flex-wrap:wrap;margin-top:var(--s4)}
.chip{border:1px solid var(--line);border-radius:var(--r-sm);padding:3px 8px;
  font-size:10.5px;color:var(--dim);letter-spacing:.05em}
.chip[aria-pressed="true"]{border-color:var(--lime);color:var(--lime)}

.site-footer{border-top:1px solid var(--line);margin-top:var(--s8);
  padding:var(--s5) 0 var(--s7);color:var(--dim);font-size:12px}
.site-footer a:hover{color:var(--lime)}
.site-footer ul{list-style:none;padding:0;margin:0;display:flex;gap:var(--s4);flex-wrap:wrap}

/* Prose on the dark shell — project descriptions only. Article bodies use article.css. */
.prose-dark{max-width:60ch;color:var(--dim);font-size:14.5px;line-height:1.7;
  padding:var(--s5) 0 0}
.prose-dark p{margin:0 0 var(--s4)}
.prose-dark strong{color:var(--paper);font-weight:500}
.prose-dark a{color:var(--lime);text-decoration:underline;text-underline-offset:2px}
.prose-dark code{background:var(--ink-2);padding:2px 5px;border-radius:var(--r-sm);
  color:var(--paper);font-size:.9em}
.prose-dark pre{background:var(--ink-2);padding:var(--s4);border-radius:var(--r-md);
  overflow-x:auto;font-size:13px}
.prose-dark pre code{background:none;padding:0}
.prose-dark ul,.prose-dark ol{padding-left:1.3em;margin:0 0 var(--s4)}

/* Homepage bio paragraph — same treatment as prose-dark's dim/width/spacing, own class
   because it's a single line of text, not a prose block. */
.bio{color:var(--dim);max-width:34em;padding:var(--s4) 0}

/* Reveals. DEFAULT IS VISIBLE — see plan note. Only enhances. */
@supports (animation-timeline:view()){
  @media (prefers-reduced-motion:no-preference){
    @keyframes rise{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}
    .reveal{animation:rise .5s var(--ease) both;animation-timeline:view();
      animation-range:entry 0% cover 22%}
  }
}
@media (prefers-reduced-motion:no-preference){
  @view-transition{navigation:auto}
}
@media (max-width:640px){
  .row{grid-template-columns:1fr;gap:var(--s1)}
  .wrap{padding:0 var(--s4)}
}
```

- [ ] **Step 3: Run the assertion to verify it passes**

```bash
tools/assert.sh "grain filter inlined" 'feTurbulence' assets/css/site.css
tools/assert.sh "press physics present" 'translateY\(1px\)' assets/css/site.css
tools/assert.sh "reveal defaults visible (inside @supports)" '@supports \(animation-timeline' assets/css/site.css
```

Expected: three `PASS` lines.

**Why the third assertion matters:** if `.reveal` were declared with `opacity:0` outside `@supports`, every browser without scroll-timeline support would render a blank page — a silent failure invisible in your own browser. The rule is that `opacity:0` only ever appears inside a keyframe, never as a base state.

- [ ] **Step 4: Commit**

```bash
git add assets/css/site.css
git commit -m "feat: design tokens, reset, tactility layer"
```

---

## Task 5: Base layout, head, header, footer

**Files:**
- Create: `_layouts/base.html`, `_layouts/page.html`, `_includes/head.html`, `_includes/header.html`, `_includes/footer.html`
- Modify: `index.md`

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null && tools/assert.sh "primary nav exists" 'aria-label="Primary"' _site/index.html
```

Expected: FAIL — no header include exists yet.

**Why this assertion and not a `baseurl` one.** The obvious choice —
`assert.sh "nav uses baseurl" 'href="/PersonalPage/writing/"'` — does **not** discriminate here: the
Task 1 placeholder homepage already contains a `relative_url` link to `/writing/`, so that pattern
passes before any header exists. An assertion that cannot fail proves nothing. `aria-label="Primary"`
appears only in the header this task creates.

- [ ] **Step 2: Write the includes and layouts**

`_includes/head.html`:

```html
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
{%- comment -%}
  Anti-flash for the clack toggle, same idea as a dark-mode flash guard: read the stored
  preference and stamp a class on <html> before first paint, so the switch renders in the
  right position immediately. clack.js (deferred) is still the sole owner of aria-pressed
  and audio — this just prevents the visible/AT-state mismatch until it runs. localStorage
  can throw in some privacy modes, hence the try/catch; failure just means default OFF.
{%- endcomment -%}
<script>try{if(localStorage.getItem('clack')==='1')document.documentElement.classList.add('clack-on')}catch(e){}</script>
{%- comment -%}
  fonts.css is linked directly rather than @imported from site.css. A CSS @import is only
  discovered after the importing sheet is fetched AND parsed, which serialised the font CSS
  and its @font-face files behind site.css — measured at ~150ms of avoidable critical-path
  delay. Linked here they fetch in parallel.
{%- endcomment -%}
<link rel="stylesheet" href="{{ '/assets/css/fonts.css' | relative_url }}">
<link rel="stylesheet" href="{{ '/assets/css/site.css' | relative_url }}">
{% if page.surface == 'bone' %}<link rel="stylesheet" href="{{ '/assets/css/article.css' | relative_url }}">
<link rel="stylesheet" href="{{ '/assets/css/rouge.css' | relative_url }}">{% endif %}
<link rel="alternate" type="application/atom+xml" title="{{ site.title }}" href="{{ '/feed.xml' | relative_url }}">
<link rel="preload" as="font" type="font/woff2" crossorigin
      href="{{ '/assets/fonts/JetBrainsMono-Regular.woff2' | relative_url }}">
{% seo %}
{%- comment -%}
  Nil-safe on purpose: Liquid evaluates nil != "" as true, so a bare inequality would emit a
  live script tag with an empty subdomain if this key were ever renamed or dropped.
{%- endcomment -%}
{% if site.goatcounter and site.goatcounter != "" %}
<script data-goatcounter="https://{{ site.goatcounter }}.goatcounter.com/count"
        async src="//gc.zgo.at/count.js"></script>
{% endif %}
```

`_includes/header.html`:

```html
<header class="site-header">
  <div class="wrap">
    <a class="brand" href="{{ '/' | relative_url }}"><b>kovs705</b> — {{ site.author }}</a>
    <nav class="site-nav" aria-label="Primary">
      <a href="{{ '/writing/' | relative_url }}" {% if page.section == 'writing' %}aria-current="page"{% endif %}>writing</a>
      <a href="{{ '/projects/' | relative_url }}" {% if page.section == 'projects' %}aria-current="page"{% endif %}>projects</a>
      <a href="{{ '/about/' | relative_url }}" {% if page.section == 'about' %}aria-current="page"{% endif %}>about</a>
      <button class="clack" type="button" aria-pressed="false" data-clack
              title="Sound by Clackable — my Swift package">
        clack <span class="sw" aria-hidden="true"></span>
      </button>
    </nav>
  </div>
</header>
```

`_includes/footer.html`:

```html
<footer class="site-footer">
  <div class="wrap">
    <ul>
      <li><a href="mailto:{{ site.email }}">{{ site.email }}</a></li>
      <li><a href="https://github.com/{{ site.social.github }}" rel="me noreferrer">GitHub</a></li>
      <li><a href="https://t.me/{{ site.social.telegram }}" rel="noreferrer">Telegram</a></li>
      <li><a href="https://www.linkedin.com/in/{{ site.social.linkedin }}/" rel="me noreferrer">LinkedIn</a></li>
      <li><a href="{{ '/cv/' | relative_url }}">CV</a></li>
      <li><a href="{{ '/feed.xml' | relative_url }}">Feed</a></li>
    </ul>
  </div>
</footer>
```

`_layouts/base.html`:

```html
<!doctype html>
<html lang="{{ site.lang }}">
<head>{% include head.html %}</head>
<body class="{% if page.surface == 'bone' %}on-bone{% endif %}">
  {% include header.html %}
  {{ content }}
  {% include footer.html %}
  <script src="{{ '/assets/js/clack.js' | relative_url }}" defer></script>
  <script src="{{ '/assets/js/copy.js' | relative_url }}" defer></script>
  <script src="{{ '/assets/js/tilt.js' | relative_url }}" defer></script>
  {% if page.section == 'writing' and page.layout == 'page' %}
  <script src="{{ '/assets/js/filter.js' | relative_url }}" defer></script>
  {% endif %}
</body>
</html>
```

`_layouts/page.html`:

```html
---
layout: base
---
<main class="wrap grain" id="main">
  <div class="hero hero-tight">
    <h1>{{ page.title }}</h1>
    {% if page.dek %}<p class="dek">{{ page.dek }}</p>{% endif %}
  </div>
  {{ content }}
</main>
```

Replace **`index.html`** with a temporary shim so the assertion can pass. (The file is
`index.html`, not `index.md` — Task 1 renamed it because kramdown silently escaped raw HTML inside
a `.md` file while the build reported success.)

```markdown
---
layout: page
title: Home
---
```

- [ ] **Step 3: Run the assertion to verify it passes**

```bash
tools/build.sh >/dev/null && tools/assert.sh "nav uses baseurl" 'href="/PersonalPage/writing/"' _site/index.html
tools/validate-content.sh
```

Expected: `PASS`, then `validate-content: OK`.

- [ ] **Step 4: Commit**

```bash
git add _layouts _includes index.md
git commit -m "feat: base layout, head, header, footer"
```

---

## Task 6: Projects collection content

The featured set is taken verbatim from the owner's GitHub profile README. Dragula is excluded at his request.

**Files:**
- Create: 10 files in `_projects/`, plus `_data/tools.yml`

- [ ] **Step 1: Write the assertion first**

```bash
test $(ls _projects/*.md 2>/dev/null | wc -l) -eq 10 && echo PASS || echo "FAIL: expected 10 project files"
```

Expected: `FAIL`.

- [ ] **Step 2: Create the seven packages**

Each file follows this exact shape. `_projects/goldenhour.md`:

```markdown
---
title: "GoldenHour"
tagline: "Sun position, twilight phases, golden & blue hours, and sky gradient colours"
repo: kovs705/GoldenHour
kind: package
license: MIT
status: active
featured: true
order: 3
---

Computes sun position, twilight phases, golden and blue hour windows, and matching
sky gradient colours from a time and a location. No network calls — everything is
derived locally from the date and coordinates.
```

Create the remaining six with the same structure and these values:

| File | title | tagline | repo | order |
|---|---|---|---|---|
| `accessdenied.md` | `"AccessDenied"` | `"Hide sensitive content in SwiftUI"` | `kovs705/AccessDenied` | 1 |
| `clackable.md` | `"Clackable"` | `"Duolingo and Nintendo sound feel, for SwiftUI"` | `kovs705/Clackable` | 2 |
| `previewdebugger.md` | `"PreviewDebugger"` | `"Accessibility, UI and locale in your SwiftUI preview environment"` | `kovs705/PreviewDebugger` | 4 |
| `notchtransition.md` | `"NotchTransition"` | `"Custom navigation transition from the iPhone notch"` | `kovs705/NotchTransition` | 5 |
| `tokenedittttor.md` | `"TokenEdittttor"` | `"Text editor that shows available AI tokens (UIKit/SwiftUI)"` | `kovs705/TokenEdittttor` | 6 |
| `mdedittttor.md` | `"MDEdittttor"` | `"Markdown editor package (UIKit/SwiftUI)"` | `kovs705/MDEdittttor` | 7 |

All seven use `kind: package`, `status: active`, `featured: true`. Each needs a one- or two-sentence
body. Orders 1–4 are the four repos pinned on the owner's profile.

**Licences are per-repo, NOT uniformly MIT.** An earlier draft of this plan asserted `license: MIT`
for all seven; two of them have no licence at all. Verified against
`https://api.github.com/repos/kovs705/<name>` → `license.spdx_id`:

| repo | actual | front matter |
|---|---|---|
| AccessDenied, GoldenHour, PreviewDebugger, NotchTransition, TokenEdittttor | `MIT` | `license: MIT` |
| **Clackable**, **MDEdittttor** | `null` — no `LICENSE` file in the repo | **omit `license:` entirely** |

Omission, not `license: none` or `license: ""`. This matters more than it looks: the site's premise is
that every rendered row is a fact a reader can check, so asserting MIT on a repo with no licence is
the one defect class that undermines everything else on the page. Note that Clackable's own README
renders a shields.io "License: MIT" badge pointing at a file that does not exist — the owner's README
is aspirational there, which is exactly why the site must not copy the claim.

Re-verify these before writing the files; a licence may legitimately have been added since.

**Bodies must be sourced, not inferred.** Write only what the repo description or README actually
states. A review caught "shows the AI tokens available *as you type*" for TokenEdittttor — the editor
and the token indicator are documented, but the live-update behaviour was invented. When the source
does not say, write one shorter sentence instead of two. For BagLog the owner's README says only
"Yet another ambitious project, but this is it" — so `In active development.` is the honest body, and
inventing a purpose would be worse than saying little.

- [ ] **Step 3: Create the three in-progress apps**

`_projects/baglog.md`:

```markdown
---
title: "BagLog"
tagline: "Yet another ambitious project, but this is the one"
repo: kovs705/BagLog
kind: app
status: coming-soon
featured: true
order: 1
---

In active development. The devlog for this project is below.
```

`_projects/squidnote.md`:

```markdown
---
title: "SquidNote"
tagline: "Squiddy-Labs — App Store submission pending"
kind: app
status: coming-soon
featured: true
order: 2
---

A large project in progress. App Store release coming.
```

`_projects/obsidian-wall.md`:

```markdown
---
title: "Obsidian Wall"
tagline: "App Store submission pending"
kind: app
status: coming-soon
featured: true
order: 3
---

In progress. More detail once it ships.
```

Note `squidnote.md` and `obsidian-wall.md` deliberately omit `repo:` — `validate-content.sh`
permits this only when `status: coming-soon`, which is exactly the case being modelled.

- [ ] **Step 4: Create `_data/tools.yml`**

```yaml
- name: "Plist2Hex.py"
  note: "Convert an Xcode theme to a list of HEX colours with titles"
  url: "https://gist.github.com/kovs705/ea416d65697ef469c9526465ec6706ce"
- name: "iOS 26 Glass"
  note: "Support the new Glass effect without errors"
  url: "https://gist.github.com/kovs705/06c770c288e726cb5f862917f899de71"
- name: "KMP .gitignore"
  note: "Git ignore template for iOS and Kotlin Multiplatform projects"
  url: "https://github.com/kovs705/KMP-git-ignore"
- name: "iOS Scripts"
  note: "Four scripts and executable apps"
  url: "https://github.com/kovs705/iOSScripts"
- name: "Xcode 15.2 runtime headers"
  note: "Headers of Xcode under the hood"
  url: "https://github.com/kovs705/Xcode15-RuntimeHeaders"
- name: "Useful links"
  note: "A small list of links for better development"
  url: "https://gist.github.com/kovs705/c047c7fb17e0bb788997e7a87b33bb52"
```

- [ ] **Step 5: Run the assertion and validation to verify they pass**

```bash
test $(ls _projects/*.md | wc -l) -eq 10 && echo PASS || echo FAIL
tools/validate-content.sh && tools/build.sh >/dev/null
tools/assert.sh "project page built" 'sun position' _site/projects/goldenhour/index.html
```

Expected: `PASS`, `validate-content: OK`, `PASS`.

The assertion greps **body text**, not the title, on purpose: `_layouts/project.html` doesn't
exist until Task 7, so at this point Jekyll emits the rendered Markdown body with no layout
around it. Asserting on the title would fail here for a reason that has nothing to do with the
content being correct.

- [ ] **Step 6: Commit**

```bash
git add _projects _data/tools.yml
git commit -m "content: ten curated projects and tools data"
```

---

## Task 7: Project layout, package row, and projects index

**Files:**
- Create: `_layouts/project.html`, `_includes/copy-button.html`, `_includes/package-row.html`,
  `_includes/entry-row.html`, `projects.html`

**Note `projects.html`, not `projects.md`.** The body is pure Liquid and HTML with no Markdown prose,
and kramdown auto-wraps a non-block `<button>` in a `<p>`, which put accidental 15px UA-default
margins around every copy button. `.html` skips kramdown entirely. The same applies to `writing.html`,
`devlog.html`, and `tags.html` in Tasks 11 and 15 — those are also pure Liquid, so they are `.html` too.

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null
tools/assert.sh "projects index groups packages" '01 / PACKAGES' _site/projects/index.html
```

Expected: FAIL — no `projects.md` yet.

- [ ] **Step 2: Write the includes**

`_includes/copy-button.html` — expects `include.repo` and `include.name`. Extracted because the same
markup is needed by both the package row and the project page, and Task 12's `copy.js` depends on the
exact `data-copy` / `data-copy-label` contract — divergence between two copies would silently break
one of them. The `aria-label` matters: without it the accessible name is the raw clone URL, so a
screen-reader user tabbing `/projects/` hears eight long near-identical URLs read out in full.

```html
<button class="copy" type="button" aria-label="Copy clone URL for {{ include.name }}"
        data-copy="https://github.com/{{ include.repo }}.git">
  <span>https://github.com/{{ include.repo }}.git</span><b data-copy-label>copy</b>
</button>
```

`_includes/package-row.html` — expects `include.p`:

```html
{% assign p = include.p %}
<div class="row" data-tilt>
  <span class="row-title">
    <a href="{{ p.url | relative_url }}">{{ p.title }}</a>
    <em>— {{ p.tagline }}</em>
  </span>
  <span class="row-meta">
    {% if p.version %}v{{ p.version }} · {% endif %}
    {%- comment -%}
      Two packages genuinely have no licence (see Task 6), so this must say so rather than
      render blank — a silently empty cell reads as an oversight, and "no licence" is
      information a developer actually wants before installing.
    {%- endcomment -%}
    {% if p.status == 'coming-soon' %}coming soon{% else %}{{ p.license | default: 'no licence' }}{% endif %}
    {% if p.repo %} · <button class="copy-inline" type="button"
        aria-label="Copy clone URL for {{ p.title }}"
        data-copy="https://github.com/{{ p.repo }}.git"><span data-copy-label>copy</span></button>{% endif %}
  </span>
</div>
```

`_includes/entry-row.html` — expects `include.e`, used by home, `/writing/`, `/devlog/`, and project pages:

```html
{% assign e = include.e %}
{% assign kind = 'devlog' %}
{% if e.collection == 'articles' %}{% assign kind = 'article' %}{% endif %}
<a class="row" href="{{ e.url | relative_url }}" data-kind="{{ kind }}"
   data-tags="{{ e.tags | join: ' ' }}">
  <span class="row-title">{{ e.title }}</span>
  <span class="row-meta">
    {{ kind }} · {{ e.date | date: "%Y-%m-%d" }}{% if e.project %} · {{ e.project }}{% endif %}
  </span>
</a>
```

- [ ] **Step 3: Write `_layouts/project.html`**

```html
---
layout: base
---
<main class="wrap grain" id="main">
  <div class="hero hero-tight">
    <h1>{{ page.title }}</h1>
    <p class="dek">{{ page.tagline }}</p>
    <div class="chips">
      <span class="chip">{{ page.kind }}</span>
      <span class="chip">{% if page.status == 'coming-soon' %}coming soon{% else %}{{ page.status }}{% endif %}</span>
      {% if page.license %}<span class="chip">{{ page.license }}</span>{% endif %}
      {% if page.version %}<span class="chip">v{{ page.version }}</span>{% endif %}
    </div>
    {% if page.repo %}
    <div class="hero-cta">
      <a class="btn" href="https://github.com/{{ page.repo }}" rel="noreferrer">View on GitHub →</a>
    </div>
    <div style="margin-top:var(--s4)">
      {% include copy-button.html repo=page.repo name=page.title %}
    </div>
    {% endif %}
  </div>

  <div class="prose-dark">{{ content }}</div>

  {% assign log = site.devlog | where: "project", page.slug | sort: "date" | reverse %}
  {% if log.size > 0 %}
    <div class="lbl"><h2>BUILD LOG</h2><span>{{ log.size }} ENTR{% if log.size == 1 %}Y{% else %}IES{% endif %}</span></div>
    {% for e in log %}{% include entry-row.html e=e %}{% endfor %}
  {% endif %}
</main>
```

- [ ] **Step 4: Write `projects.html`**

```markdown
---
layout: page
title: Projects
section: projects
permalink: /projects/
dek: "Seven packages you can install now, three apps in progress, and a handful of gists."
---

{% assign packages = site.projects | where: "kind", "package" | sort: "order" %}
{% assign apps = site.projects | where: "kind", "app" | sort: "order" %}

<div class="lbl"><h2>01 / PACKAGES</h2><span>SWIFTPM</span></div>
{% for p in packages %}{% include package-row.html p=p %}{% endfor %}

<div class="lbl"><h2>02 / IN PROGRESS</h2><span>APPS</span></div>
{% for p in apps %}{% include package-row.html p=p %}{% endfor %}

{% if site.data.tools and site.data.tools.size > 0 %}
<div class="lbl"><h2>03 / GISTS &amp; TOOLS</h2><span>EXTERNAL</span></div>
{% for t in site.data.tools %}
<a class="row" href="{{ t.url }}" rel="noreferrer">
  <span class="row-title">{{ t.name }} <em>— {{ t.note }}</em></span>
  <span class="row-meta">↗</span>
</a>
{% endfor %}
{% endif %}
```

- [ ] **Step 5: Run the assertions to verify they pass**

```bash
tools/build.sh >/dev/null
tools/assert.sh "projects index groups packages" '01 / PACKAGES' _site/projects/index.html
tools/assert.sh "tools block rendered" 'Plist2Hex' _site/projects/index.html
tools/assert.sh "copy target on project page" 'data-copy="https://github.com/kovs705/GoldenHour.git"' _site/projects/goldenhour/index.html
tools/validate-content.sh
```

Expected: three `PASS` lines and `validate-content: OK`.

- [ ] **Step 6: Commit**

```bash
git add _layouts/project.html _includes/copy-button.html _includes/package-row.html \
        _includes/entry-row.html projects.html
git commit -m "feat: project pages and projects index"
```

---

## Task 8: Homepage

**Files:**
- Create: `_layouts/home.html`
- Modify: `index.md`

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null && tools/assert.sh "hero knockout present" 'class="knock"' _site/index.html
```

Expected: FAIL.

- [ ] **Step 2: Write `_layouts/home.html`**

```html
---
layout: base
---
<main class="wrap grain" id="main">
  <section class="hero">
    <h1>I ship iOS apps and <span class="knock">write down</span> the parts that fought back.</h1>
    <p class="dek">{{ site.description }} Based in Buenos Aires, working remote.</p>
    <div class="hero-cta">
      <a class="btn" href="{{ '/devlog/' | relative_url }}">Read the devlog →</a>
      <a class="btn ghost" href="https://github.com/{{ site.social.github }}" rel="noreferrer">GitHub</a>
    </div>
  </section>

  {% assign packages = site.projects | where: "kind", "package" | sort: "order" %}
  {% assign apps = site.projects | where: "kind", "app" | sort: "order" %}
  {% assign articles = site.articles | sort: "date" | reverse %}
  {% assign entries = site.devlog | sort: "date" | reverse %}

  <div class="lbl reveal"><h2>01 / PACKAGES</h2><span>SWIFTPM · TAP TO COPY</span></div>
  {% for p in packages %}{% include package-row.html p=p %}{% endfor %}

  <div class="lbl reveal"><h2>02 / IN PROGRESS</h2><span>APPS</span></div>
  {% for p in apps %}{% include package-row.html p=p %}{% endfor %}

  {% if articles.size > 0 or entries.size > 0 %}
  <div class="lbl reveal"><h2>03 / WRITING</h2>
    <span><a href="{{ '/writing/' | relative_url }}">ALL →</a></span></div>
  {% for e in articles limit: 3 %}{% include entry-row.html e=e %}{% endfor %}
  {% for e in entries limit: 3 %}{% include entry-row.html e=e %}{% endfor %}
  {% endif %}

  <div class="lbl reveal"><h2>04 / WHO</h2><span><a href="{{ '/about/' | relative_url }}">MORE →</a></span></div>
  <p class="bio">
    Apple platform developer. SwiftUI, UIKit, some Kotlin Multiplatform. Healthcare and
    logistics in production. A happy dad, average Nintendo enjoyer, and fan of
    microcontrollers and single-board computers.
  </p>
</main>
```

**Note on the writing block:** articles and devlog entries are listed in two separate loops
rather than merged and sorted. `concat` on two collections then `sort` works, but keeping them
separate here guarantees both kinds appear on a homepage even when one collection is much
larger — which is the actual goal of this block. The globally-sorted merge lives on `/writing/`.

- [ ] **Step 3: Replace `index.md`**

```markdown
---
layout: home
title: "Eugene Rozhkov — iOS developer"
section: home
---
```

- [ ] **Step 4: Run assertions to verify they pass**

```bash
tools/build.sh >/dev/null
tools/assert.sh "hero knockout present" 'class="knock"' _site/index.html
tools/assert.sh "packages block" '01 / PACKAGES' _site/index.html
tools/assert.sh "seven package rows" 'MDEdittttor' _site/index.html
tools/assert.sh "apps block" 'BagLog' _site/index.html
```

Expected: four `PASS` lines.

- [ ] **Step 5: Commit**

```bash
git add _layouts/home.html index.md
git commit -m "feat: homepage"
```

---

## Task 9: Article surface — layout, bone CSS, Rouge, content includes

**Files:**
- Create: `_layouts/article.html`, `assets/css/article.css`, `assets/css/rouge.css`, `_includes/figure.html`, `_includes/note.html`, `_includes/video.html`

- [ ] **Step 1: Write the assertion first**

```bash
tools/assert.sh "bone surface defined" '--bone' assets/css/article.css
```

Expected: FAIL — missing file.

- [ ] **Step 2: Write `_layouts/article.html`**

```html
---
layout: base
---
<main class="bone-surface grain-paper" id="main">
  <article class="prose {% if page.collection == 'devlog' %}is-entry{% endif %}">
    <header class="prose-head">
      {% if page.collection %}
      <p class="kicker">
        {% if page.collection == 'devlog' %}Devlog{% else %}Article{% endif %}
        · <time datetime="{{ page.date | date_to_xmlschema }}">{{ page.date | date: "%d %B %Y" }}</time>
      </p>
      {% endif %}
      <h1>{{ page.title }}</h1>
      {% if page.description %}<p class="lede">{{ page.description }}</p>{% endif %}

      {% if page.project %}
        {% assign proj = site.projects | where: "slug", page.project | first %}
        {% assign siblings = site.devlog | where: "project", page.project | sort: "date" %}
        {% assign idx = 0 %}
        {% for s in siblings %}{% if s.url == page.url %}{% assign idx = forloop.index %}{% endif %}{% endfor %}
        {% if proj %}
        <p class="in-project">
          {% if idx > 0 %}Entry {{ idx }} of {{ siblings.size }} in the{% else %}Part of the{% endif %}
          <a href="{{ proj.url | relative_url }}">{{ proj.title }}</a> build log
        </p>
        {% endif %}
      {% endif %}
    </header>

    {{ content }}

    {% if page.tags %}
    <p class="prose-tags">
      {% for t in page.tags %}<a href="{{ '/tags/' | relative_url }}#{{ t | slugify }}">#{{ t }}</a> {% endfor %}
    </p>
    {% endif %}

    {% if page.project and siblings %}
      {% assign previdx = idx | minus: 1 %}
      {% assign nextidx = idx | plus: 1 %}
      {% assign prev = null %}{% assign next = null %}
      {% for s in siblings %}
        {% if forloop.index == previdx %}{% assign prev = s %}{% endif %}
        {% if forloop.index == nextidx %}{% assign next = s %}{% endif %}
      {% endfor %}
      <nav class="prose-nav">
        {% if prev %}<a href="{{ prev.url | relative_url }}">← {{ prev.title }}</a>{% endif %}
        {% if next %}<a href="{{ next.url | relative_url }}">{{ next.title }} →</a>{% endif %}
      </nav>
    {% endif %}
  </article>
</main>
```

The `defaults` block in `_config.yml` (Task 1) already assigns `layout: article` and
`surface: bone` to both collections, so `head.html` pulls in the bone stylesheets automatically.
No config change is needed here, and the layout warnings from Task 1 stop after this task.

**Fix the prev/next computation carefully.** Liquid cannot evaluate a filter inside a
comparison — `{% if forloop.index == idx | minus: 1 %}` does not work and fails silently,
producing no navigation at all. The indices must be computed into variables first, which is why
the layout above assigns `previdx` and `nextidx` before the loop.

- [ ] **Step 3: Write `assets/css/article.css`**

```css
/* The reading surface. Density and tactility stop at this boundary. */
.bone-surface{background:var(--bone);color:var(--article-ink);
  padding:var(--s8) var(--s5);position:relative}
.grain-paper::before{content:"";position:absolute;inset:0;pointer-events:none;
  opacity:.07;mix-blend-mode:multiply;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3'/%3E%3C/filter%3E%3Crect width='120' height='120' filter='url(%23n)'/%3E%3C/svg%3E")}

.prose{position:relative;z-index:1;max-width:66ch;margin:0 auto;
  font:400 19px/1.65 var(--serif)}
.prose.is-entry{max-width:60ch;font-size:18px}

.prose-head{margin-bottom:var(--s7)}
.kicker{font:500 11px/1 var(--mono);letter-spacing:.12em;text-transform:uppercase;
  color:#6E6A5C;margin:0 0 var(--s4)}
.prose-head h1{font-family:var(--display);font-size:clamp(28px,5vw,42px);line-height:1.05;
  color:var(--article-ink)}
.prose.is-entry .prose-head h1{font-size:clamp(24px,4vw,32px)}
.lede{font-size:20px;line-height:1.55;color:#4A463C;margin:var(--s4) 0 0}
.in-project{font:400 13px/1.5 var(--mono);color:#6E6A5C;margin:var(--s4) 0 0}
.in-project a{color:var(--tomato-ink);text-decoration:underline;text-underline-offset:2px}

.prose h2,.prose h3{font-family:var(--display);margin:var(--s7) 0 var(--s3);
  color:var(--article-ink);line-height:1.15}
.prose h2{font-size:27px}
.prose h3{font-size:21px}
.prose p{margin:0 0 var(--s5)}
.prose a{color:var(--article-ink);text-decoration:underline;
  text-decoration-color:var(--tomato);text-underline-offset:3px;text-decoration-thickness:2px}
.prose ul,.prose ol{margin:0 0 var(--s5);padding-left:1.3em}
.prose li{margin-bottom:var(--s2)}
.prose blockquote{margin:var(--s5) 0;padding-left:var(--s4);
  border-left:3px solid var(--tomato);color:#4A463C;font-style:italic}
.prose hr{border:0;border-top:1px solid var(--bone-2);margin:var(--s7) 0}
.prose code{font:400 .85em/1.5 var(--mono);background:rgba(21,20,15,.06);
  padding:2px 5px;border-radius:var(--r-sm)}
.prose pre{background:var(--ink);color:var(--paper);padding:var(--s4);
  border-radius:var(--r-md);overflow-x:auto;font-size:13.5px;line-height:1.55;
  margin:0 0 var(--s5)}
.prose pre code{background:none;padding:0;font-size:inherit;color:inherit}
.prose table{width:100%;border-collapse:collapse;font-size:16px;margin:0 0 var(--s5)}
.prose th,.prose td{text-align:left;padding:var(--s2) var(--s3);
  border-bottom:1px solid var(--bone-2)}

figure{margin:var(--s6) 0}
figure img{border-radius:var(--r-md);border:1px solid var(--bone-2)}
figcaption{font:400 13px/1.5 var(--mono);color:#6E6A5C;margin-top:var(--s2)}

.note{margin:var(--s5) 0;padding:var(--s4);border-radius:var(--r-md);
  border-left:3px solid var(--tomato);background:rgba(21,20,15,.04);
  font-size:17px;line-height:1.6}
.note.info{border-left-color:#2B6E8A}
.note.caution{border-left-color:#B8860B}
.note>:last-child{margin-bottom:0}

.prose-tags{font:400 13px/1.6 var(--mono);color:#6E6A5C;margin:var(--s7) 0 0}
.prose-tags a{color:#6E6A5C;text-decoration:none}
.prose-tags a:hover{color:var(--tomato-ink)}
.prose-nav{display:flex;justify-content:space-between;gap:var(--s4);flex-wrap:wrap;
  border-top:1px solid var(--bone-2);margin-top:var(--s6);padding-top:var(--s4);
  font:400 14px/1.5 var(--mono)}
.prose-nav a{color:var(--article-ink)}
.prose-nav a:hover{color:var(--tomato-ink)}

/* Focus ring must be visible on bone too — lime would fail contrast here. */
.bone-surface :focus-visible{outline:2px solid var(--tomato);outline-offset:2px}

@media (max-width:640px){.bone-surface{padding:var(--s6) var(--s4)}.prose{font-size:17.5px}}
```

- [ ] **Step 4: Write `assets/css/rouge.css`**

```css
/* Rouge tokens, tuned for the dark code block on bone paper. */
.highlight{background:none}
.highlight .c,.highlight .c1,.highlight .cm,.highlight .cs{color:#6C7266;font-style:italic}
.highlight .k,.highlight .kd,.highlight .kn,.highlight .kp,.highlight .kr,.highlight .kt{color:#C9F227}
.highlight .kc{color:#C9F227}
.highlight .s,.highlight .s1,.highlight .s2,.highlight .sb,.highlight .sc,.highlight .sd,
.highlight .se,.highlight .sh,.highlight .si,.highlight .sx,.highlight .sr,.highlight .ss{color:#E8B84B}
.highlight .m,.highlight .mf,.highlight .mh,.highlight .mi,.highlight .mo,.highlight .il{color:#7FD1B9}
.highlight .n,.highlight .na,.highlight .nb,.highlight .nx{color:#E4E6E9}
.highlight .nc,.highlight .nn,.highlight .no{color:#8ECBF0}
.highlight .nf,.highlight .nd{color:#F3F0E7;font-weight:500}
.highlight .nt{color:#C9F227}
.highlight .nv,.highlight .vc,.highlight .vg,.highlight .vi{color:#E4E6E9}
.highlight .o,.highlight .ow,.highlight .p{color:#9BA2AB}
.highlight .err,.highlight .gr{color:#FF6B5E}
.highlight .gi{color:#7FD1B9}
.highlight .gd{color:#FF6B5E}
.highlight .gh,.highlight .gu{color:#8ECBF0;font-weight:500}
```

- [ ] **Step 5: Write the content includes**

`_includes/figure.html`:

```html
{% assign dir = page.collection | default: 'img' %}
<figure>
  <img src="{{ '/assets/img/' | append: dir | append: '/' | append: page.slug | append: '/' | append: include.src | relative_url }}"
       alt="{{ include.alt }}" width="{{ include.width }}" height="{{ include.height }}" loading="lazy" decoding="async">
  {% if include.caption %}<figcaption>{{ include.caption }}</figcaption>{% endif %}
</figure>
```

`_includes/note.html`:

```html
<div class="note {{ include.type | default: 'info' }}">{{ include.body | markdownify }}</div>
```

`_includes/video.html`:

```html
{% assign dir = page.collection | default: 'img' %}
<figure>
  <video controls preload="metadata" width="{{ include.width }}" height="{{ include.height }}"
    {% if include.poster %}poster="{{ '/assets/img/' | append: dir | append: '/' | append: page.slug | append: '/' | append: include.poster | relative_url }}"{% endif %}>
    <source src="{{ '/assets/img/' | append: dir | append: '/' | append: page.slug | append: '/' | append: include.src | relative_url }}" type="video/mp4">
  </video>
  {% if include.caption %}<figcaption>{{ include.caption }}</figcaption>{% endif %}
</figure>
```

- [ ] **Step 6: Run assertions to verify they pass**

```bash
tools/assert.sh "bone surface defined" '--bone' assets/css/article.css
tools/assert.sh "measure set to 66ch" '66ch' assets/css/article.css
tools/assert.sh "focus visible on bone" 'bone-surface :focus-visible' assets/css/article.css
tools/build.sh >/dev/null && echo "build OK"
```

Expected: three `PASS` lines and `build OK`.

- [ ] **Step 7: Commit**

```bash
git add _layouts/article.html assets/css/article.css assets/css/rouge.css _includes/figure.html _includes/note.html _includes/video.html _config.yml
git commit -m "feat: article reading surface with Rouge and content includes"
```

---

## Task 10: Seed content — one article, two devlog entries, external writing

Real content is needed to verify the templates, and the site must not launch with empty indexes.

**Files:**
- Create: `_data/external_writing.yml`, `_articles/why-i-rebuilt-my-site.md`, `_devlog/2026-07-28-building-this-site.md`

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null
tools/assert.sh "article renders on bone" 'class="prose' _site/writing/why-i-rebuilt-my-site/index.html
```

Expected: FAIL — file does not exist.

- [ ] **Step 2: Create `_data/external_writing.yml`**

The existing dev.to/Habr article is linked, never copied — republishing text that already ranks
makes it compete with itself.

```yaml
- title: "Abstraction in Swift: a comparative look at Kotlin and Swift"
  venue: "dev.to"
  date_display: "2023"
  url: "https://dev.to/kovs705/abstraction-in-swift-a-comparative-look-at-kotlin-and-swift-4ole"
  summary: "How abstraction differs between Swift and Kotlin, with side-by-side examples."
- title: "Абстракция в Swift: сравнение с Kotlin"
  venue: "Habr"
  date_display: "2023"
  url: "https://habr.com/ru/articles/782834/"
  summary: "Russian version of the same comparison."
```

`date_display` is a **string**, deliberately. A YAML `Date` here would tempt a future merge into
a Liquid `sort` alongside document `Time` objects, which raises at build time.

- [ ] **Step 3: Create `_articles/why-i-rebuilt-my-site.md`**

```markdown
---
title: "Why I rebuilt my site around a devlog"
date: 2026-07-28
description: "My old resume page made claims. This one shows version numbers, dates, and the parts that fought back."
tags: [meta, writing]
---

My previous site told visitors I "think beyond ticket execution." It was true, and it was
useless — a claim with nothing behind it. Anyone can write that sentence.

So this version is built on a different rule: **every row on the homepage is a fact you can
check.** A version number, a licence, a date, a commit. If a sentence can't be verified, it
doesn't belong on the front page.

## What changed structurally

The devlog attaches to projects. Each entry carries an optional `project` field, so a
three-sentence note about a gesture conflict becomes part of a build history rather than
disappearing into a chronological feed.

{% include note.html type="info" body="This site is static — Jekyll on GitHub Pages, no build step I run locally. The whole publishing flow is one Markdown file and one `git push`." %}

## What I cut

Stat cards claiming "4 human languages studied." A three-language switcher wrapped around one
page of text. Stock 3D illustrations of a glossy phone. None of it survived the rule above.
```

- [ ] **Step 4: Create `_devlog/2026-07-28-building-this-site.md`**

```markdown
---
title: "Grain is doing most of the work"
date: 2026-07-28
tags: [css, design]
---

Spent the evening on the tactile feel of the shell and the finding is almost embarrassing: a
single inline SVG `feTurbulence` overlay at 16% opacity accounts for most of what reads as
"physical."

The other half is press physics — one rule, applied everywhere:

```css
.btn:active{transform:translateY(1px);box-shadow:1px 1px 0 rgba(201,242,39,.28)}
```

Eighty milliseconds. That's the entire difference between a page and a panel of keys.
```

Note: no `project:` field on this entry — it's about the site itself, which is not in
`_projects/`. `validate-content.sh` only checks `project:` when present.

- [ ] **Step 5: Run assertions to verify they pass**

```bash
tools/validate-content.sh && tools/build.sh >/dev/null
tools/assert.sh "article renders on bone" 'class="prose' _site/writing/why-i-rebuilt-my-site/index.html
tools/assert.sh "note include rendered" 'class="note info"' _site/writing/why-i-rebuilt-my-site/index.html
tools/assert.sh "rouge highlighted the css block" 'highlight' _site/devlog/building-this-site/index.html
tools/assert.sh "bone stylesheet linked" 'article.css' _site/writing/why-i-rebuilt-my-site/index.html
```

Expected: `validate-content: OK` and four `PASS` lines.

- [ ] **Step 6: Commit**

```bash
git add _articles _devlog _data/external_writing.yml
git commit -m "content: seed article, devlog entry, external writing data"
```

---

## Task 11: Writing index, devlog index, and the filter

**Files:**
- Create: `writing.html`, `devlog.html`, `assets/js/filter.js`  (pure Liquid — `.html` skips kramdown)

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null && tools/assert.sh "writing index merges both collections" 'data-kind="article"' _site/writing/index.html
```

Expected: FAIL.

- [ ] **Step 2: Write `writing.html`**

```markdown
---
layout: page
title: Writing
section: writing
permalink: /writing/
dek: "Articles when something deserves the full argument. Devlog when it doesn't."
---

{% assign all = site.articles | concat: site.devlog | sort: "date" | reverse %}

<div class="chips" role="group" aria-label="Filter writing by kind">
  <button class="chip" type="button" data-filter="all" aria-pressed="true">all</button>
  <button class="chip" type="button" data-filter="article" aria-pressed="false">articles</button>
  <button class="chip" type="button" data-filter="devlog" aria-pressed="false">devlog</button>
</div>

<div id="writing-list">
{% for e in all %}{% include entry-row.html e=e %}{% endfor %}
</div>

<div class="lbl"><span>PUBLISHED ELSEWHERE</span><span>EXTERNAL</span></div>
{% for x in site.data.external_writing %}
<a class="row" href="{{ x.url }}" rel="noreferrer">
  <span class="row-title">{{ x.title }} <em>— {{ x.summary }}</em></span>
  <span class="row-meta">{{ x.venue }} · {{ x.date_display }} ↗</span>
</a>
{% endfor %}
```

`site.articles | concat: site.devlog | sort: "date"` is safe — both sides are Jekyll documents
with `Time` dates. The external data block stays separate precisely because its dates are strings.

- [ ] **Step 3: Write `devlog.html`**

```markdown
---
layout: page
title: Devlog
section: writing
permalink: /devlog/
dek: "Short entries, dated, often mid-problem. Entries tagged with a project also collect on that project's page."
---

{% assign entries = site.devlog | sort: "date" | reverse %}
{% assign current_month = "" %}
{% for e in entries %}
  {% assign month = e.date | date: "%B %Y" %}
  {% if month != current_month %}
    <div class="lbl"><span>{{ month }}</span><span></span></div>
    {% assign current_month = month %}
  {% endif %}
  {% include entry-row.html e=e %}
{% endfor %}
```

- [ ] **Step 4: Write `assets/js/filter.js`**

```javascript
// Progressive enhancement only. With JS off every row stays visible, which is the correct failure.
(() => {
  const chips = document.querySelectorAll('[data-filter]');
  const rows = document.querySelectorAll('#writing-list [data-kind]');
  if (!chips.length || !rows.length) return;

  chips.forEach(chip => chip.addEventListener('click', () => {
    const want = chip.dataset.filter;
    chips.forEach(c => c.setAttribute('aria-pressed', String(c === chip)));
    rows.forEach(r => {
      r.hidden = want !== 'all' && r.dataset.kind !== want;
    });
  }));
})();
```

- [ ] **Step 5: Run assertions to verify they pass**

```bash
tools/build.sh >/dev/null
tools/assert.sh "writing index merges both collections" 'data-kind="article"' _site/writing/index.html
tools/assert.sh "devlog rows present" 'data-kind="devlog"' _site/writing/index.html
tools/assert.sh "external block rendered" 'PUBLISHED ELSEWHERE' _site/writing/index.html
tools/assert.sh "devlog index groups by month" 'July 2026' _site/devlog/index.html
```

Expected: four `PASS` lines.

- [ ] **Step 6: Commit**

```bash
git add writing.html devlog.html assets/js/filter.js
git commit -m "feat: writing and devlog indexes with filter"
```

---

## Task 12: JavaScript enhancements — clack, copy, tilt

**Files:**
- Create: `assets/js/clack.js`, `assets/js/copy.js`, `assets/js/tilt.js`

- [ ] **Step 1: Write the assertion first**

```bash
tools/assert.sh "clack synthesizes audio" 'AudioContext' assets/js/clack.js
```

Expected: FAIL — missing file.

**One thing Task 5's review surfaced that this task must handle.** `header.html` hardcodes
`aria-pressed="false"` on the toggle, and `site.css` styles the switch off `[aria-pressed="true"]`.
A `defer`red script therefore leaves a returning visitor who enabled sound looking at the wrong
switch position — and assistive tech announcing the wrong state — until the script runs. Restoring
the stored state needs a **small blocking inline script in `head.html`**, the same pattern used to
prevent dark-mode flash. `clack.js` keeps owning the audio and the click handler; only the initial
state read has to happen before first paint.

- [ ] **Step 2: Write `assets/js/clack.js`**

```javascript
// Clackable, ported to the web. Synthesized — no audio file ships.
// Default OFF. Only fires on real interaction, so autoplay policy is never an issue.
(() => {
  const KEY = 'clack';
  const toggle = document.querySelector('[data-clack]');
  let on = localStorage.getItem(KEY) === '1';
  let ctx = null;

  const setState = () => {
    if (toggle) toggle.setAttribute('aria-pressed', String(on));
    document.documentElement.classList.toggle('clack-on', on);
  };

  // Short filtered noise burst with a fast decay — reads as a clack, not a beep.
  const click = (down) => {
    if (!on) return;
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      const dur = down ? 0.014 : 0.010;
      const frames = Math.floor(ctx.sampleRate * dur);
      const buf = ctx.createBuffer(1, frames, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < frames; i++) {
        // Linear decay envelope over white noise.
        data[i] = (Math.random() * 2 - 1) * (1 - i / frames);
      }
      const src = ctx.createBufferSource();
      src.buffer = buf;
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = down ? 2100 : 2800;
      bp.Q.value = 0.9;
      const gain = ctx.createGain();
      gain.gain.value = down ? 0.32 : 0.20;
      src.connect(bp).connect(gain).connect(ctx.destination);
      src.start();
    } catch (_) { /* audio unavailable — silently do nothing */ }
  };

  setState();

  if (toggle) {
    toggle.addEventListener('click', (e) => {
      e.preventDefault();
      on = !on;
      localStorage.setItem(KEY, on ? '1' : '0');
      setState();
      if (on) click(true);   // confirm by demonstrating
    });
  }

  const selector = '.btn, .copy, .copy-inline, a.row, .site-nav a, .chip';
  document.addEventListener('pointerdown', (e) => {
    if (e.target.closest(selector) && !e.target.closest('[data-clack]')) click(true);
  });
  document.addEventListener('pointerup', (e) => {
    if (e.target.closest(selector) && !e.target.closest('[data-clack]')) click(false);
  });
})();
```

- [ ] **Step 3: Write `assets/js/copy.js`**

```javascript
(() => {
  document.querySelectorAll('[data-copy]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const text = btn.dataset.copy;
      const label = btn.querySelector('[data-copy-label]');
      const restore = label ? label.textContent : '';
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          const ta = document.createElement('textarea');
          ta.value = text;
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          document.body.appendChild(ta);
          ta.select();
          document.execCommand('copy');
          document.body.removeChild(ta);
        }
        if (label) label.textContent = 'copied ✓';
      } catch (_) {
        if (label) label.textContent = 'select & copy';
      }
      if (label) setTimeout(() => { label.textContent = restore; }, 1400);
    });
  });
})();
```

- [ ] **Step 4: Write `assets/js/tilt.js`**

```javascript
// Cursor-reactive tilt, capped at 3deg. Pointer-precise devices only, motion-preference aware.
(() => {
  if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const MAX = 3;
  document.querySelectorAll('[data-tilt]').forEach(el => {
    el.style.transition = 'transform 180ms cubic-bezier(.2,.8,.3,1)';
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      const dx = (e.clientX - r.left) / r.width - 0.5;
      const dy = (e.clientY - r.top) / r.height - 0.5;
      el.style.transform =
        `perspective(600px) rotateY(${(dx * MAX * 2).toFixed(2)}deg) rotateX(${(-dy * MAX * 2).toFixed(2)}deg)`;
    });
    el.addEventListener('pointerleave', () => { el.style.transform = ''; });
  });
})();
```

- [ ] **Step 5: Run assertions to verify they pass**

```bash
tools/assert.sh "clack synthesizes audio" 'AudioContext' assets/js/clack.js
tools/assert.sh "clack defaults off" "localStorage.getItem\(KEY\) === '1'" assets/js/clack.js
tools/assert.sh "copy has execCommand fallback" 'execCommand' assets/js/copy.js
tools/assert.sh "tilt respects reduced motion" 'prefers-reduced-motion' assets/js/tilt.js
tools/build.sh >/dev/null && cat _site/assets/js/*.js | wc -c
```

Expected: four `PASS` lines, and a total well under 8000 bytes unminified (the 4KB budget is post-minification).

- [ ] **Step 6: Commit**

```bash
git add assets/js/clack.js assets/js/copy.js assets/js/tilt.js
git commit -m "feat: clack, copy, and tilt enhancements"
```

---

## Task 13: About page

**Files:**
- Create: `about.md`

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null && tools/assert.sh "about page built" 'happy dad' _site/about/index.html
```

Expected: FAIL.

- [ ] **Step 2: Write `about.md`**

The voice comes straight from the owner's GitHub profile README, which is already right.

```markdown
---
layout: article
surface: bone
section: about
title: "About"
permalink: /about/
date: 2026-07-28
---

Hello! こんにちは! Привет! Terve! ¡Hola!

I'm Eugene — a happy dad, Apple platform developer, average Nintendo enjoyer, and a fan of
microcontrollers and single-board computers. I live in Buenos Aires and work remote.

## What I build

iOS, mostly. SwiftUI and UIKit in production, some Kotlin Multiplatform where sharing logic
actually pays for itself. My professional work has been in **healthcare** and **logistics** —
domains where the interface being wrong is not a cosmetic problem.

Alongside that I publish [Swift packages]({{ '/projects/' | relative_url }}): sun-position
maths, tactile UI sound, preview tooling, transitions, editors. Small, single-purpose, and
installable in about thirty seconds.

## How I work

I have relocated across countries with my family, which is a reasonable proxy for adapting
quickly and communicating directly. I prefer async, written, and specific. I would rather ship
something and write down what broke than plan something and describe what might.

That's what the [devlog]({{ '/devlog/' | relative_url }}) is for.

## Elsewhere

- [GitHub](https://github.com/kovs705) — packages, gists, and 80-odd repos
- [Telegram](https://t.me/kovs705) — fastest for a direct conversation
- [LinkedIn](https://www.linkedin.com/in/kovs705/)
- [Email](mailto:EuKovs@gmail.com) — best for role discussions
- [CV]({{ '/cv/' | relative_url }}) — dates and scope
```

- [ ] **Step 3: Run assertions to verify they pass**

```bash
tools/build.sh >/dev/null
tools/assert.sh "about page built" 'happy dad' _site/about/index.html
tools/assert.sh "about links use baseurl" '/PersonalPage/devlog/' _site/about/index.html
```

Expected: two `PASS` lines.

- [ ] **Step 4: Commit**

```bash
git add about.md
git commit -m "content: about page"
```

---

## Task 14: CV page and print stylesheet

**Files:**
- Create: `cv.md`, `_layouts/cv.html`, `assets/css/print.css`

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null && tools/assert.sh "cv print stylesheet linked" 'print.css' _site/cv/index.html
```

Expected: FAIL.

- [ ] **Step 2: Write `_layouts/cv.html`**

```html
---
layout: base
---
<main class="bone-surface" id="main">
  <article class="prose cv">
    <header class="prose-head">
      <h1>{{ site.author }}</h1>
      <p class="lede">{{ site.tagline }}</p>
      <p class="kicker">
        Buenos Aires, Argentina · <a href="mailto:{{ site.email }}">{{ site.email }}</a>
        · github.com/{{ site.social.github }} · linkedin.com/in/{{ site.social.linkedin }}
      </p>
    </header>
    {{ content }}
  </article>
</main>
<link rel="stylesheet" href="{{ '/assets/css/print.css' | relative_url }}" media="print">
```

- [ ] **Step 3: Write `cv.md`**

Dates and employers are placeholders **only** where the owner must supply private facts the
repo does not contain. Every structural element is complete.

```markdown
---
layout: cv
surface: bone
section: about
title: "CV — Eugene Rozhkov"
permalink: /cv/
date: 2026-07-28
---

Mid iOS developer, 4+ years shipping production mobile apps. Kotlin Multiplatform integration and
SwiftUI product delivery, mostly in MedTech and service apps. Modular architecture, CI/CD automation,
distributed international teams.

## Experience

### iOS Developer — Lifetime Health Plus Care Pvt Ltd
**February 2024 – present** · Remote, Bengaluru, India

- Build and maintain a production iOS app for ordering home healthcare services in India.
- Ship features in SwiftUI with Kotlin Multiplatform bridges for shared cross-platform logic.
- Own the CI/CD flow — Xcode Cloud, GitHub, and custom pre/post-build scripts.
- Released on the App Store:
  [Lifetime Health](https://apps.apple.com/jp/app/lifetime-health/id6496204102?l=en-US).

### Lead iOS Developer — RESHENIE LLC
**June 2023 – March 2024** · Remote, Saint Petersburg, Russia

- Led two iOS developers across several MedTech projects.
- Improved application performance and reinforced architecture quality across the portfolio.
- Built a reusable Kotlin Multiplatform core library to speed delivery across products.
- Established CI/CD pipelines in self-hosted GitLab for delivery consistency.

### Contract iOS Developer — Individual Entrepreneur
**March 2022 – November 2022** · Saint Petersburg, Russia

- Modernised a legacy logistics application for cargo transportation status tracking.
- Integrated SwiftUI into an existing UIKit codebase.
- Migrated desktop-only functionality to mobile.

## Open source

Seven published Swift packages — see [projects]({{ '/projects/' | relative_url }}).
Highlights: **GoldenHour** (sun position and twilight maths), **Clackable** (tactile UI
sound), **PreviewDebugger** (accessibility and locale in SwiftUI previews),
**AccessDenied** (sensitive-content masking).

## Technical

**Platforms:** iOS, iPadOS, macOS
**Languages:** Swift, Kotlin (KMP)
**UI:** SwiftUI, UIKit, SwiftData / Core Data
**Cross-platform:** Kotlin Multiplatform
**Architecture:** Modular, with Tuist / XcodeGen
**Delivery:** Xcode Cloud, GitHub Actions, GitLab CI, Swift Package Manager

## Education

**Togliatti State University** — Togliatti, Russia
BSc Computer Science, remote. Expected graduation 2028.

## Writing

Published on dev.to and Habr; ongoing articles and a development log at
[this site]({{ '/writing/' | relative_url }}).

## Languages

English (working), Russian (native), Spanish (conversational — resident in Argentina),
Japanese and Finnish (studied).

## Relocation

Has relocated internationally with family more than once. Comfortable in distributed,
async-first teams across time zones.
```

- [ ] **Step 4: Write `assets/css/print.css`**

```css
@media print{
  .site-header,.site-footer,.clack,.prose-nav,.prose-tags{display:none !important}
  .grain::before,.grain-paper::before{display:none !important}
  html,body{background:#fff !important;color:#000 !important}
  .bone-surface{background:#fff !important;padding:0 !important}
  .prose{max-width:none;font-size:10.5pt;line-height:1.45;color:#000}
  .prose-head h1{font-size:20pt}
  .lede{font-size:11pt;color:#000}
  .kicker{font-size:8.5pt;color:#000}
  .prose h2{font-size:12.5pt;margin:14pt 0 5pt;border-bottom:.5pt solid #000;padding-bottom:2pt}
  .prose h3{font-size:11pt;margin:9pt 0 2pt}
  .prose p,.prose li{margin-bottom:4pt}
  .prose a{color:#000;text-decoration:none}
  .prose a::after{content:""}
  h2,h3{break-after:avoid}
  @page{margin:14mm}
}
```

- [ ] **Step 5: Run assertions to verify they pass**

```bash
tools/build.sh >/dev/null
tools/assert.sh "cv print stylesheet linked" 'print.css' _site/cv/index.html
tools/assert.sh "cv experience section" 'Experience' _site/cv/index.html
```

Expected: two `PASS` lines.

Then verify manually: open `http://localhost:4000/PersonalPage/cv/` via `tools/serve.sh`, press
⌘P, and confirm the header, footer, and clack toggle are absent and the document is one to two
clean pages.

- [x] **Step 6: Owner supplied employment dates and employers — RESOLVED**

This was the only genuinely unavailable information in the whole plan: nothing in the repository,
the GitHub profile, or PVresume states employers or dates. The owner provided a CV PDF, and the
real history turned out to be **three** roles, not the two this plan assumed — Lifetime Health
Plus Care (Feb 2024–present), RESHENIE LLC as lead across MedTech projects (Jun 2023–Mar 2024),
and a logistics modernisation contract (Mar–Nov 2022). Experience corrected to 4+ years, and
education added.

**The phone number on the PDF was deliberately omitted.** It is appropriate on a document handed
to a named recipient; a public page indexed by search engines is a different exposure, and email,
Telegram and LinkedIn already cover contact. Apply the same judgement to anything else personal
that arrives via a CV.

**The CV also surfaced the strongest evidence the site was missing:** Lifetime Health is live on
the App Store. For a site built on "every row is a fact you can check", a shipped app is the most
checkable artifact there is, and it existed nowhere on the site. Now linked from `/about/` and
`/cv/`.

- [ ] **Step 7: Commit**

```bash
tools/assert.sh "no CV placeholders remain" '^' cv.md
grep -q 'to be filled in by owner' cv.md && { echo "FAIL: CV still has placeholders"; exit 1; } || echo "PASS: CV complete"
git add cv.md _layouts/cv.html assets/css/print.css
git commit -m "feat: CV page with print stylesheet"
```

---

## Task 15: Tags page and 404

**Files:**
- Create: `tags.html`, `404.html`  (pure Liquid — `.html` skips kramdown)

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null && tools/assert.sh "tags page groups by tag" 'id="css"' _site/tags/index.html
```

Expected: FAIL. (`css` is a real tag on the Task 10 seed devlog entry; `swiftui` is not yet used
by any seed content, so asserting on it would pass vacuously later.)

- [ ] **Step 2: Write `tags.html`**

`jekyll-archives` is not available on GitHub Pages, so one page carries every tag as an anchor.

```markdown
---
layout: page
title: Tags
section: writing
permalink: /tags/
dek: "Everything, grouped. GitHub Pages can't generate per-tag pages without an unsupported plugin, so this is one page with anchors."
---

{% assign all = site.articles | concat: site.devlog %}
{% assign tags = all | map: "tags" | compact | join: "," | split: "," | uniq | sort %}

<div class="chips">
{% for t in tags %}<a class="chip" href="#{{ t | slugify }}">#{{ t }}</a>{% endfor %}
</div>

{% for t in tags %}
  <div class="lbl" id="{{ t | slugify }}"><h2>#{{ t }}</h2><span></span></div>
  {% assign tagged = all | where_exp: "e", "e.tags contains t" | sort: "date" | reverse %}
  {% for e in tagged %}{% include entry-row.html e=e %}{% endfor %}
{% endfor %}
```

- [ ] **Step 3: Write `404.html`**

This is the one page where humour costs nothing.

```html
---
layout: page
title: "404"
permalink: /404.html
dek: "This path doesn't exist. Statistically that's my fault, not yours."
---

<p class="bio">
  I moved something, mistyped a link, or shipped a devlog entry at 2am. Any of those is
  plausible. Nothing here is your doing.
</p>

<div class="hero-cta">
  <a class="btn" href="{{ '/' | relative_url }}">Back to the start</a>
  <a class="btn ghost" href="{{ '/writing/' | relative_url }}">Everything I've written</a>
</div>
```

- [ ] **Step 4: Run assertions to verify they pass**

```bash
tools/build.sh >/dev/null
tools/assert.sh "tags page groups by tag" 'id="css"' _site/tags/index.html
tools/assert.sh "404 built at root" 'Back to the start' _site/404.html
```

Expected: two `PASS` lines.

- [ ] **Step 5: Commit**

```bash
git add tags.html 404.html
git commit -m "feat: tags page and 404"
```

---

## Task 16: Hand-written Atom feed

`jekyll-feed` would build `/feed.xml` from `_posts` (unused here) and, pointed at collections,
emits separate per-collection feeds while `/feed.xml` stays empty. One canonical merged feed
is the goal, so the template is written by hand.

**Files:**
- Create: `feed.xml`

- [ ] **Step 1: Write the assertion first**

```bash
tools/build.sh >/dev/null
grep -c '<entry>' _site/feed.xml 2>/dev/null || echo "FAIL: no feed"
```

Expected: `FAIL: no feed`.

- [ ] **Step 2: Write `feed.xml`**

```liquid
---
layout: null
permalink: /feed.xml
---
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>{{ site.title | xml_escape }}</title>
  <subtitle>{{ site.description | xml_escape }}</subtitle>
  <id>{{ '/feed.xml' | absolute_url }}</id>
  <link rel="alternate" type="text/html" href="{{ '/' | absolute_url }}"/>
  <link rel="self" type="application/atom+xml" href="{{ '/feed.xml' | absolute_url }}"/>
  <author><name>{{ site.author | xml_escape }}</name><email>{{ site.email }}</email></author>
  {% assign all = site.articles | concat: site.devlog | sort: "date" | reverse %}
  <updated>{% if all.first %}{{ all.first.date | date_to_xmlschema }}{% else %}{{ site.time | date_to_xmlschema }}{% endif %}</updated>
  {% for e in all limit: 30 %}
  <entry>
    <title>{{ e.title | xml_escape }}</title>
    <link rel="alternate" type="text/html" href="{{ e.url | absolute_url }}"/>
    <id>{{ e.url | absolute_url }}</id>
    <published>{{ e.date | date_to_xmlschema }}</published>
    <updated>{{ e.date | date_to_xmlschema }}</updated>
    <category term="{% if e.collection == 'articles' %}article{% else %}devlog{% endif %}"/>
    {% for t in e.tags %}<category term="{{ t | xml_escape }}"/>{% endfor %}
    <summary type="text">{% if e.description %}{{ e.description | xml_escape }}{% else %}{{ e.excerpt | strip_html | normalize_whitespace | truncate: 300 | xml_escape }}{% endif %}</summary>
    <content type="html">{{ e.content | strip_newlines | xml_escape }}</content>
  </entry>
  {% endfor %}
</feed>
```

- [ ] **Step 3: Run assertions to verify they pass**

```bash
tools/build.sh >/dev/null
test "$(grep -c '<entry>' _site/feed.xml)" -ge 2 && echo "PASS: feed has entries from both collections" || echo FAIL
tools/assert.sh "feed marks articles" 'term="article"' _site/feed.xml
tools/assert.sh "feed marks devlog" 'term="devlog"' _site/feed.xml
tools/assert.sh "feed uses absolute urls" 'https://kovs705.github.io/PersonalPage/' _site/feed.xml
python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse('_site/feed.xml'); print('PASS: feed is well-formed XML')"
```

Expected: five `PASS` lines.

The well-formedness check matters because a stray unescaped `&` in a title silently produces a
feed no reader can parse.

- [ ] **Step 4: Commit**

```bash
git add feed.xml
git commit -m "feat: hand-written Atom feed merging both collections"
```

---

## Task 17: Authoring tools and analytics

**Files:**
- Create: `tools/new-article.sh`, `tools/new-devlog.sh`, `tools/optimize-image.sh`
- Modify: `_config.yml`

- [ ] **Step 1: Write the assertion first**

```bash
tools/new-devlog.sh "Test entry" 2>/dev/null && echo PASS || echo "FAIL: script missing"
```

Expected: `FAIL: script missing`.

- [ ] **Step 2: Write the scaffolding scripts**

`tools/new-devlog.sh`:

```bash
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
```

`tools/new-article.sh`:

```bash
#!/usr/bin/env bash
# new-article.sh "Title here" [project-slug]
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -ge 1 ] || { echo "usage: $0 \"Title\" [project-slug]"; exit 1; }
title="$1"; project="${2:-}"
slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
file="_articles/${slug}.md"
[ -e "$file" ] && { echo "exists: $file"; exit 1; }
{
  echo "---"
  echo "title: \"${title//\"/\\\"}\""
  echo "date: $(date +%Y-%m-%d)"
  echo "description: \"One sentence — jekyll-seo-tag reads this for the meta description and link preview.\""
  [ -n "$project" ] && echo "project: ${project}"
  echo "tags: []"
  echo "---"
  echo
} > "$file"
mkdir -p "assets/img/articles/${slug}"
echo "$file"
```

`tools/optimize-image.sh` — uses `sips` and `cwebp`, both confirmed present. No ImageMagick.

```bash
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
```

```bash
chmod +x tools/new-devlog.sh tools/new-article.sh tools/optimize-image.sh
```

- [ ] **Step 3: Set the GoatCounter code**

The site owner must register a code at <https://www.goatcounter.com> (free, no cookies, no
consent banner needed). Then set it in `_config.yml`:

```yaml
goatcounter: "kovs705"
```

Leaving it as `""` disables the script entirely — `head.html` already guards on it, so the
site works either way and this never blocks the build.

- [ ] **Step 4: Run assertions to verify they pass**

```bash
f=$(tools/new-devlog.sh "Scaffold smoke test" baglog) && echo "created $f"
tools/assert.sh "scaffold prefills date" 'date: 20' "$f"
tools/assert.sh "scaffold prefills project" 'project: baglog' "$f"
tools/validate-content.sh
rm -f "$f" && rm -rf assets/img/devlog/*scaffold-smoke-test*
tools/validate-content.sh
```

Expected: two `PASS` lines and `validate-content: OK` both times. The scaffold is deleted
because it was only a test of the tool.

- [ ] **Step 5: Commit**

```bash
git add tools/new-devlog.sh tools/new-article.sh tools/optimize-image.sh _config.yml
git commit -m "feat: authoring scripts and analytics config"
```

---

## Task 18: Deploy and full verification

**Files:**
- Create: `README.md`
- Modify: none

- [ ] **Step 1: Write `README.md`**

```markdown
# PersonalPage

Personal site of Eugene Rozhkov — articles, development log, and Swift packages.
Live at <https://kovs705.github.io/PersonalPage/>.

Jekyll on GitHub Pages. No build step runs locally in normal use: write Markdown, `git push`,
GitHub builds it.

## Publish a devlog entry

    tools/new-devlog.sh "The gesture conflict took four days" baglog
    # write Markdown; put images in the created assets/img/devlog/<slug>/ folder
    tools/optimize-image.sh assets/img/devlog/<slug>/*.png
    tools/validate-content.sh
    git add -A && git commit -m "devlog: gesture conflict" && git push

## Local preview

Host Ruby is too new for Jekyll 3.10, so builds run in Docker:

    tools/serve.sh     # http://localhost:4000/PersonalPage/
    tools/build.sh     # one-shot build into _site/

## Before pushing

    tools/validate-content.sh    # front matter, dangling refs, absolute paths, image size
    tools/test-validate.sh       # unit tests for the validator

## Rules that will bite you

- Every internal path must use `{{ '/x' | relative_url }}`. The site is served from
  `/PersonalPage`, so a bare `/writing/` 404s in production.
- Quote every `title:`. An unquoted colon breaks the YAML and fails the build.
- `_articles` and `_devlog` files need an explicit `date:` — collections do not read it from
  the filename.
- `repository:` must stay in `_config.yml` or the build fails outright.
```

- [ ] **Step 2: Enable GitHub Pages and push**

```bash
tools/test-validate.sh && tools/validate-content.sh && tools/build.sh >/dev/null && echo "ready"
git add README.md && git commit -m "docs: README with authoring workflow"
git push -u origin main
```

Then, in the repository on github.com: **Settings → Pages → Build and deployment → Source:
Deploy from a branch → Branch: `main` / `(root)`**. Save.

Wait for the build to finish (Actions tab, or the Pages section shows the live URL). If the
build fails, GitHub emails the owner and **keeps serving the last good build** — a bad push
degrades to stale, never to down.

- [ ] **Step 3: Verify the deployed site**

```bash
BASE=https://kovs705.github.io/PersonalPage
for p in / /writing/ /devlog/ /projects/ /projects/goldenhour/ /about/ /cv/ /tags/ /feed.xml /sitemap.xml /404.html; do
  printf "%-28s " "$p"; curl -s -o /dev/null -w "%{http_code}\n" "$BASE$p"
done
```

Expected: `200` for every path except `/404.html`, which may return `200` or `404` depending on
how GitHub serves it — both are fine.

```bash
# No absolute-path leaks reached production:
curl -s $BASE/ | grep -oE '(href|src)="/[a-zA-Z][^"]*"' | grep -v '/PersonalPage/' || echo "PASS: no baseurl leaks"
# Feed has both kinds:
curl -s $BASE/feed.xml | grep -c 'term="devlog"'
```

- [ ] **Step 4: The unfurl test — the acceptance test for the whole architecture**

Paste `https://kovs705.github.io/PersonalPage/writing/why-i-rebuilt-my-site/` into **Telegram**
and into **Slack**. Each must render a card showing the title *"Why I rebuilt my site around a
devlog"* and the summary text.

This is the reason Jekyll was chosen over client-side Markdown rendering. If the card is blank,
the architecture did not deliver what it was picked for — check that `{% seo %}` is in
`head.html` and that `url` and `baseurl` in `_config.yml` are correct.

- [ ] **Step 5: Run the manual verification matrix**

Record the result of each. Every one is a spec requirement, not a nicety.

- [ ] **JavaScript disabled** (DevTools → Settings → Debugger → Disable JavaScript). Every page
      renders fully; no blank sections; `/writing/` shows all rows; copy buttons are inert but
      the URLs are readable and selectable.
- [ ] **`prefers-reduced-motion: reduce`** (DevTools → Rendering → Emulate CSS media). Tilt,
      scroll reveals, and view transitions are gone; the 1px press drop still works.
- [ ] **Keyboard only.** Tab through the homepage and `/writing/`. A lime focus ring is visible
      at every stop on dark surfaces, tomato on bone. No focus trap; no invisible stop.
- [ ] **320px width.** No horizontal scroll; rows stack; code blocks scroll inside themselves.
- [ ] **1440px width.** Content stays within the 960px measure; nothing stretches.
- [ ] **Print `/cv/`.** ⌘P shows one to two clean pages, no header, no footer, no clack toggle,
      no grain.
- [ ] **Clack toggle.** Default off on a fresh profile. Toggling on produces a click; the state
      survives a reload.
- [ ] **Contrast.** Check with any contrast tool: lime `#C9F227` on `#121310` (expect ~15:1);
      body ink `#15140F` on bone `#F2EFE6` (expect >12:1). Confirm tomato `#E8422C` is never
      used for body-size text on bone — it is ~3.9:1 and fails AA below 24px.

- [ ] **Step 6: Lighthouse**

Run Lighthouse (DevTools → Lighthouse, Mobile) on three pages:

- `/` — home template
- `/writing/why-i-rebuilt-my-site/` — article template
- `/projects/goldenhour/` — project template

Targets: **performance ≥95, accessibility 100, best practices ≥95.** If accessibility is below
100, the cause is almost always a missing `alt`, a heading-level skip, or a link whose only
content is an icon.

- [ ] **Step 7: Validate markup and feed**

Submit each of the three template URLs to <https://validator.w3.org/nu/> and `/feed.xml` to
<https://validator.w3.org/feed/>. Fix anything reported.

- [ ] **Step 8: Retire PVresume**

The spec makes this site the replacement. In the `PVresume` repository, add a `README.md` note
pointing here, and update the GitHub profile README link from
`https://kovs705.github.io/PVresume/` to `https://kovs705.github.io/PersonalPage/`.

Do not delete `PVresume` — the old URL may be linked from places neither of us controls, and
leaving it serving is free.

- [ ] **Step 9: Final commit**

```bash
tools/validate-content.sh && git status --short
git add -A && git commit -m "chore: verification pass complete" || echo "nothing to commit"
git push
```

---

## Definition of done

- [ ] All eleven routes return 200 at the deployed subpath URL.
- [ ] A new devlog entry publishes with one Markdown file and one `git push`.
- [ ] A project page auto-collects its devlog entries with no duplicated maintenance.
- [ ] Site fully usable with JavaScript disabled.
- [ ] Lighthouse: performance ≥95, accessibility 100 on home, article, and project templates.
- [ ] `/feed.xml` is well-formed and contains entries from both collections.
- [ ] Unfurl test passes on Telegram and Slack.
- [ ] `tools/validate-content.sh` and `tools/test-validate.sh` both pass.
- [ ] No absolute internal paths in production output.
- [ ] `cv.md` contains no `to be filled in by owner` markers.
- [ ] Profile README link updated from `PVresume` to `PersonalPage`.
