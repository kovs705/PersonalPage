# Personal Site — Design Spec

**Date:** 2026-07-27
**Owner:** Eugene Rozhkov (`kovs705`)
**Repo:** `kovs705/PersonalPage`
**Deployed:** `https://kovs705.github.io/PersonalPage/`
**Status:** Approved, ready for implementation planning

---

## 1. Purpose

A single personal site that replaces the existing `PVresume` page. It carries long-form articles, a development log, project pages for published Swift packages, an about page, and a CV.

The site is **peer-led**: the articles and devlog are the substance, and the hiring case is what that substance proves. A visiting iOS developer should find something worth reading and an installable package; a hiring manager should reach the same conclusion by reading evidence rather than claims.

`PVresume` is retired once this ships. Its useful content — career history, relocation timeline, contact links — moves to `/about/` and `/cv/`. Its stat cards ("4 human languages studied", "3 countries lived in") are cut, because they are unverifiable claims of exactly the kind this site is designed to stop making.

### Why the current site fails

Diagnosed from the live page, so the redesign targets real causes rather than assumed ones. The typography is not the problem — the display sizing, warm cream on near-black, and hierarchy are all sound. Three other things read as junior:

1. **Stock 3D icon illustrations** (glossy phone, Japanese castle) — decorative filler that says nothing about the work, and the loudest template signal on the page.
2. **No evidence.** Claims like "think beyond ticket execution" with no code, screenshots, or installable artifacts to back them.
3. **Chrome outweighs content.** A floating pill nav, a heavy dark-mode switch, and a three-language selector wrapped around one page of text.

### Success criteria

- Publishing a devlog entry costs one Markdown file and one `git push`.
- Every article URL produces a correct link-preview card when shared on Telegram and Slack.
- A project page shows its own build history without that history being maintained twice.
- The site is fully usable with JavaScript disabled.
- Nothing on the homepage is an adjective about the author.

---

## 2. Decisions and rationale

| # | Decision | Rationale |
|---|---|---|
| 1 | Replaces PVresume entirely | Splitting identity across two sites means neither accumulates. PVresume is not currently sent to anyone. |
| 2 | Peer-led audience | Verifiable substance is what reads as serious. Accepted risk: the site is only as good as what gets published. |
| 3 | Markdown authoring, rich rendering | No WYSIWYG. A browser editor would need a backend, a token in the browser, or a third-party CMS — all of which add a component that can rot. |
| 4 | Devlog entries attach to projects | One optional front-matter field turns short entries into accumulating project history. All grouping is derived. |
| 5 | English only | The chosen audience reads English. Multi-language would triple friction on the one activity the site depends on. |
| 6 | GitHub Pages' built-in Jekyll | The only option that gets Markdown authoring, prebuilt HTML for search and unfurls, and no local toolchain. See §3. |
| 7 | Repo stays `PersonalPage`; subpath URL | Owner's choice. Requires strict `baseurl` discipline — see §8.1. |
| 8 | `/about/` and `/cv/` split, print stylesheet, no PDF file | Read by different people with different questions. A print stylesheet cannot drift out of date because it is the same content. |
| 9 | Graphite/Acid Lime shell, bone paper articles | Density and tactility serve scanning; quiet serif serves reading. Different jobs, not a compromise. |

### 2.1 The constraint tension, stated plainly

The original request was "HTML/CSS/JS only." Markdown-to-HTML conversion has to happen somewhere: in the browser at read time, in the editor at write time, or on a server at push time.

Client-side rendering satisfies the constraint literally but breaks distribution. Telegram, Slack, Discord, Twitter, and Reddit fetch pages with bots that do not execute JavaScript, so every shared article would unfurl as a blank card. For a site whose strategy is peers finding and sharing writing, that is the mechanism failing rather than a detail.

Hand-authoring HTML preserves the constraint and fixes distribution, but puts friction on publishing — and a three-sentence devlog entry that requires hand-written `<figure>` markup does not get written.

GitHub Pages' Jekyll resolves all three because GitHub is the builder. The cost is honest and accepted: a `_config.yml` and layout files containing a handful of Liquid tags. There is no npm, no CI workflow, and no build command the owner ever runs. All CSS and JS remain hand-written and framework-free.

---

## 3. Architecture

**Platform:** GitHub Pages with built-in Jekyll (Jekyll 3.10 via the `github-pages` gem set). Push to `main`; GitHub builds and serves static HTML.

**Plugins** (both on the Pages allowlist): `jekyll-seo-tag`, `jekyll-sitemap`.

**The feed is hand-written, not `jekyll-feed`.** `jekyll-feed` builds `/feed.xml` from `_posts`, which this site does not use; pointing it at collections makes it emit a *separate* feed per collection (`/feed/articles.xml`, `/feed/devlog.xml`) while `/feed.xml` stays empty. Since the goal is one canonical feed URL covering both articles and devlog, a ~25-line Liquid Atom template in `feed.xml` is both simpler and correct. One fewer plugin, full control over what a subscriber receives.

**Markdown:** kramdown. **Highlighting:** Rouge, server-side at build time — zero client JS, no flash of unstyled code.

### 3.1 Repository layout

```
_config.yml
_layouts/     base.html home.html article.html project.html page.html cv.html
_includes/    head.html header.html footer.html figure.html note.html
              video.html package-row.html clack-toggle.html entry-row.html
_articles/    <slug>.md                  → /writing/:name/
_devlog/      YYYY-MM-DD-<slug>.md       → /devlog/:name/
_projects/    <slug>.md                  → /projects/:name/
assets/css/   site.css article.css rouge.css print.css
assets/js/    clack.js copy.js tilt.js filter.js
assets/fonts/ *.woff2
assets/img/<collection>/<slug>/
index.md about.md cv.md writing.md devlog.md projects.md tags.md 404.html
feed.xml      (hand-written Atom, layout: null)
tools/        optimize-image.sh validate-content.sh new-devlog.sh new-article.sh
Gemfile       (optional local preview only)
docs/superpowers/specs/
```

### 3.2 Configuration

```yaml
url: "https://kovs705.github.io"
baseurl: "/PersonalPage"
collections:
  articles: { output: true, permalink: /writing/:name/ }
  devlog:   { output: true, permalink: /devlog/:name/ }
  projects: { output: true, permalink: /projects/:name/ }
plugins: [jekyll-seo-tag, jekyll-sitemap]
```

`feed.xml` sits at the repo root with `layout: null` and merges both collections in Liquid.

### 3.3 Why three collections instead of `_posts`

Uniform treatment means one Liquid pattern everywhere, clean slugs, and no date baked into URLs.

**Known gotcha, accepted:** collections do not parse dates from filenames the way `_posts` does. **Every `_articles` and `_devlog` file must carry an explicit `date:` in front matter.** The date remains in devlog filenames for directory ordering, but Jekyll reads it from front matter only. `tools/new-devlog.sh` and `tools/new-article.sh` pre-fill it; `tools/validate-content.sh` enforces it.

### 3.4 Front matter contracts

```yaml
# _devlog/2026-03-12-gesture-conflict.md
title: "The gesture conflict took four days"   # always quoted
date: 2026-03-12                                # REQUIRED
project: dragula                                # optional; joins to _projects/dragula.md
tags: [swiftui, gestures]

# _articles/native-drag-and-drop.md
title: "Making drag & drop feel native in SwiftUI"
date: 2026-03-10                                # REQUIRED
summary: "One sentence."                        # REQUIRED — listings, meta description, OG card
image: hero.png                                 # optional; assets/img/articles/<slug>/
project: dragula                                # optional
tags: [swiftui]

# _projects/dragula.md — required: title, tagline, repo, license, status
title: "Dragula"
tagline: "Reorderable drag & drop for SwiftUI"
repo: kovs705/Dragula
version: "1.2.0"
license: MIT
status: active            # active | maintained | archived
featured: true            # surfaces on the homepage
order: 1                  # homepage ordering among featured
```

**Required fields, enforced by `validate-content.sh`:**

| Collection | Required |
|---|---|
| `_devlog` | `title`, `date` |
| `_articles` | `title`, `date`, `summary` |
| `_projects` | `title`, `tagline`, `repo`, `license`, `status` |

Devlog entries need no `summary` — listings and the feed use Jekyll's auto-excerpt (first paragraph). Articles require one because it also becomes the meta description and the unfurl card text, where an auto-excerpt reads badly.

### 3.5 Data flow

`project:` is the only join key, and all grouping is derived — nothing is maintained twice.

```liquid
{%- comment -%} project page collects its own log {%- endcomment -%}
{% assign log = site.devlog | where: "project", page.slug | sort: "date" | reverse %}

{%- comment -%} merged writing index {%- endcomment -%}
{% assign all = site.articles | concat: site.devlog | sort: "date" | reverse %}

{%- comment -%} featured packages on the homepage {%- endcomment -%}
{% assign featured = site.projects | where: "featured", true | sort: "order" %}
```

### 3.6 Version numbers are hand-entered

Reading live release data from the GitHub API would require client-side JS, which forfeits the prebuilt-HTML property that motivated the whole platform choice, and anonymous API calls are rate-limited. Updating one front-matter line when tagging a release is the cheaper trade.

### 3.7 Project curation

80 public repos are not enumerated. `featured: true` selects 5–8 with real descriptions and installable value. Starting set, to be confirmed by the owner during implementation:

Dragula, Clackable, equatable, GoldenHour, PreviewDebugger, SwiftStarter.

---

## 4. Routes and layouts

Five layouts extend `base.html`.

| Route | Layout | Contents |
|---|---|---|
| `/` | `home` | Hero with knockout headline, featured packages with copy buttons, latest 6 writing entries, short bio strip, contact footer |
| `/writing/` | `page` | Articles + devlog merged, newest first, filter chips |
| `/writing/:name/` | `article` | Bone paper, editorial serif, prev/next, linked project if any |
| `/devlog/` | `page` | Dense chronological rows grouped by month, each tagged with its project |
| `/devlog/:name/` | `article` + `.is-entry` | Same layout, modifier class tightens measure to 60ch and drops the article-scale display heading. Shows "entry 7 of 14 in the Dragula log" with in-project prev/next |
| `/projects/` | `page` | All projects grouped by `status` |
| `/projects/:name/` | `project` | Name, tagline, version, license, install line with copy button, description, screenshots, attached build log |
| `/about/` | `page` | Prose bio, photo, how you work, contact links |
| `/cv/` | `cv` | Structured history; `print.css` makes ⌘P produce a clean document |
| `/tags/` | `page` | Everything grouped by tag, anchor-addressable |
| `/404.html` | `page` | Not found |
| `/feed.xml` | none | Hand-written Atom merging `articles` + `devlog` |
| `/sitemap.xml` | — | Generated by `jekyll-sitemap` |

### 4.1 Two GitHub Pages limits, designed around

- **No per-tag pages.** `jekyll-archives` is not on the Pages allowlist. Tag chips therefore link to anchors on a single `/tags/` page, grouped in Liquid.
- **No pagination.** `jekyll-paginate` only supports `_posts`, which this site does not use. Indexes render complete. A few hundred text rows costs nothing; revisit if it exceeds ~300 entries.

### 4.2 Filters are progressive enhancement

`/writing/` renders every row in HTML. `filter.js` only hides rows. With JS disabled the page degrades to "everything visible," which is the correct failure.

---

## 5. Typography

Three self-hosted families under `assets/fonts/`, subset to Latin, `woff2`, `font-display: swap`. No CDN request, no Google Fonts, no third-party dependency.

| Family | Weights | Use |
|---|---|---|
| Cabinet Grotesk | 800 | Display headings only |
| JetBrains Mono | 400, 500 | All chrome: nav, metadata, versions, dates, tags, code |
| Source Serif 4 | 400, 600, 400 italic | Article and devlog body copy only |

Because the shell is mono-led, JetBrains Mono replaces a UI sans entirely — no Satoshi, three families instead of four, roughly six font files. Fallback stacks: `system-ui` for sans contexts, `ui-monospace, Menlo` for mono, `Georgia, serif` for body.

This satisfies the no-Inter constraint by construction.

**Article body:** 66ch measure, 1.65 line height, bone background, ink text.

---

## 6. Design system

### 6.1 Tokens

```css
:root {
  /* shell — dark, dense, mono-led */
  --ink:#121310; --ink-2:#1B1D16; --line:#26281F;
  --paper:#F3F0E7; --dim:#8E9184; --lime:#C9F227;

  /* article — bone paper, quiet, serif */
  --bone:#F2EFE6; --bone-2:#DBD6C7; --article-ink:#15140F; --tomato:#E8422C;

  --ease:cubic-bezier(.2,.8,.3,1);
  --t-press:80ms; --t-hover:180ms; --t-page:320ms;
  --r-sm:3px; --r-md:7px; --r-lg:12px;
}
```

Spacing on a 4px base. One easing curve. Three durations.

### 6.2 Accessibility constraints derived from the palette

- **Tomato `#E8422C` on bone `#F2EFE6` is ~3.9:1** — fails WCAG AA for body text. Tomato is restricted to large text (≥24px), rules, and UI accents. Article body copy is always `--article-ink`.
- **Lime `#C9F227` on graphite `#121310` is ~15:1** — safe anywhere on the shell. Lime is **dark-surface only** and never appears on bone.
- **Focus states:** 2px lime outline with 2px offset on every interactive element, on all surfaces. A dense keyboard-navigable list with invisible focus is unusable.

### 6.3 Grain

One inline SVG `feTurbulence` data URI, applied via a single `::before` with `pointer-events:none`. No image file ships.

- **Shell surfaces:** `opacity .16`, `mix-blend-mode: overlay` — reads as screen noise.
- **Bone surfaces:** `opacity .07`, `mix-blend-mode: multiply` — reads as paper tooth.

### 6.4 Press physics

Interactive elements rest on a `3px 3px 0` hard-offset shadow. On `:active`: `translateY(1px)` and shadow collapses to `1px 1px 0` over `--t-press`. Hard offsets only — no soft blurs on interactive elements.

### 6.5 The knockout headline

Lime block behind text, `rotate(-2.2deg)`, `border-radius: var(--r-sm)`. **Maximum one per page.** Used twice it stops being a gesture and becomes a texture.

Shell surfaces only, because §6.2 forbids lime on bone. On article and devlog pages the equivalent gesture uses **tomato with bone text**, which passes contrast at display sizes. Article headings are large enough for the ≥24px tomato exemption to apply.

---

## 7. Tactility and motion

### 7.1 JavaScript modules

Four modules, hand-written, zero dependencies, all `defer`. **Total budget: under 4KB minified.** If every script fails to load, the site remains fully functional.

| Module | Behaviour |
|---|---|
| `clack.js` | WebAudio synthesizes the click — no audio file ships. Filtered noise burst, ~12ms decay envelope, two variants for down/up so it reads as *clack* rather than *beep*. Toggle in the nav, state in `localStorage` under `clack`, **default off**. Fires only on real interaction, so it never trips autoplay policy. The toggle label links to the Clackable repo. |
| `copy.js` | `navigator.clipboard` with `execCommand` fallback. Button morphs to a confirmed state for 1.4s. |
| `tilt.js` | Pointer-driven card tilt, hard-capped at 3°, gated behind `@media (hover:hover) and (pointer:fine)`. |
| `filter.js` | `/writing/` filter chips. |

### 7.2 CSS-only motion

- **Scroll reveals:** `animation-timeline: view()`, `animation-range: entry 0% cover 30%`.
- **Cross-page transitions:** `@view-transition { navigation: auto; }`.

### 7.3 Mandatory implementation rule: default state is visible

Elements start at `opacity: 1`. Reveal animations are declared **inside** `@supports (animation-timeline: view())` and only enhance an already-visible element.

Building this the other way — hidden by default, revealed by animation — renders a blank page on every browser without scroll-timeline support. That failure is silent and invisible in the author's own browser. This is the single most common way scroll-reveal ships broken.

### 7.4 Reduced motion

`prefers-reduced-motion: reduce` disables tilt, scroll reveals, and view transitions. **Press states remain** — an 80ms depth change is not vestibular motion, and it is the point of the design.

---

## 8. Anti-slop constraints

Checkable rules, enforced at review:

- No gradient-blob hero.
- No glassmorphism or `backdrop-filter` panels.
- No stock 3D icons, icon packs, or generated illustrations.
- No purple-to-blue gradient.
- No Inter.
- No centered-everything layout.
- No `box-shadow` with blur radius over 8px on interactive elements.
- No copy containing "passionate," "innovative," "cutting-edge," or "I love to code."
- Screenshots are flat crops of real apps — no glossy device frames.
- Every visual element must either carry information or provide tactile feedback. Anything with neither job is cut.

**Surface boundary rule:** density and tactility stop at the article container. A grainy dark panel with clicking buttons is hostile to reading 2,000 words. Inside a post the design goes quiet — bone paper, serif, wide measure. Nothing bleeds across that boundary.

---

## 9. Authoring workflow

Publishing a devlog entry:

```bash
tools/new-devlog.sh "The gesture conflict took four days" dragula
# creates _devlog/2026-03-12-the-gesture-conflict-took-four-days.md with front matter filled
# write Markdown, drop images into assets/img/devlog/<slug>/
tools/optimize-image.sh assets/img/devlog/<slug>/*.png
tools/validate-content.sh
git add -A && git commit -m "devlog: gesture conflict" && git push
```

### 9.1 Rich content includes

```liquid
{% include figure.html src="log-1.png" alt="Description" caption="Optional caption" width="1600" height="900" %}
{% include note.html type="warning" body="Body text." %}
{% include video.html src="demo.mp4" poster="demo.jpg" width="1280" height="720" %}
```

`figure.html` emits `<figure>` with `loading="lazy"` and required explicit `width`/`height` to prevent layout shift. `note.html` accepts `type`: `info`, `warning`, `caution`. Everything else is plain Markdown — headings, lists, links, tables, fenced code blocks with a language tag.

### 9.2 Image discipline

- Max 1600px wide, ≤250KB, `.webp`.
- `tools/optimize-image.sh` wraps `cwebp`/ImageMagick.
- Git retains deleted blobs permanently, so an oversized commit is permanent repo weight that cannot be removed without rewriting history. `validate-content.sh` fails on any tracked image over 250KB.

---

## 10. Failure modes

| # | Failure | Consequence | Detection |
|---|---|---|---|
| 1 | Absolute internal path (`href="/writing/"`) | Works locally, 404s in production — the top risk given the subpath URL | `validate-content.sh` greps layouts, includes, and Markdown for absolute paths not wrapped in Liquid. All internal paths use `{{ '/x' \| relative_url }}` |
| 2 | Missing `date:` in a collection file | Entry sorts to nowhere; date formatting emits empty | Script checks required fields; `new-*.sh` pre-fills |
| 3 | Dangling `project:` value | **Silent** — entry never appears in the build log and nobody notices | Script cross-references every `project:` against `_projects/` basenames |
| 4 | Invalid YAML, usually an unquoted colon in a title | Build fails | All titles quoted in templates. GitHub emails the owner and **keeps serving the last good build** — a bad push degrades to stale, never to down |
| 5 | Oversized image committed | Permanent repo weight | Script fails on tracked images over 250KB |
| 6 | Image without dimensions | Layout shift | `figure.html` requires `width`/`height` |
| 7 | Clipboard API unavailable | Copy button inert | `execCommand` fallback; URL is selectable text regardless |
| 8 | Unknown Rouge language tag | Block renders unhighlighted | Not a crash; verified for swift, kotlin, bash, json |
| 9 | Scroll reveal built hidden-first | Blank page on unsupported browsers, silently | §7.3 rule; verified in the JS-disabled pass |

---

## 11. Verification

A static site with no build step has no test suite. That is a real weakness rather than an oversight, and the compensating controls are one script plus one checklist.

### 11.1 Automated

- **`tools/validate-content.sh`** — required front matter, dangling project refs, absolute-path leaks, oversized images. Run before every push.
- **Optional local preview** — `Gemfile` pinning the `github-pages` gem so local matches production. Requires Ruby; branch preview is an acceptable substitute.

### 11.2 Measured

- **Lighthouse** on `/`, one article, one project page. Targets: performance ≥95, accessibility 100, best practices ≥95.
- **W3C HTML validation** on the three distinct template types: `home` (`/`), `article` (one article and one devlog entry), and `project`.
- **W3C feed validation** on `/feed.xml`, confirming entries from **both** `articles` and `devlog` appear in one merged feed — the specific thing hand-writing the feed is meant to guarantee.
- **Contrast audit** of every real token pair, specifically confirming tomato never lands on bone as body text.

### 11.3 Manual matrix

- JavaScript disabled — all content reachable, filters degrade to everything-visible, no blank sections.
- `prefers-reduced-motion: reduce` — tilt, reveals, and transitions off; press states intact.
- Keyboard-only tab through the homepage and writing index — focus visible at every stop.
- 320px and 1440px viewports.
- Print preview of `/cv`.

### 11.4 The unfurl test

Paste a deployed article URL into **Telegram and Slack** and confirm a card renders with title, description, and image.

This is the acceptance test for the entire platform decision. If it fails, Jekyll did not buy what it was chosen for.

### 11.5 Definition of done

- All eleven routes render correctly at the deployed subpath URL.
- A new devlog entry is publishable with one Markdown file and one `git push`.
- A project page auto-collects its entries with no duplicated maintenance.
- Site is fully usable with JavaScript disabled.
- Lighthouse targets met on the home, article, and project templates.
- `/feed.xml` validates and contains entries from both collections.
- Unfurl test passes on both platforms.
- `validate-content.sh` passes clean.

---

## 12. Out of scope

Deliberately excluded. Each is cheap to add later; none is needed to ship.

- **Search** — not useful below roughly 50 entries.
- **Comments** — requires a third-party service and moderation.
- **Analytics** — no default. GoatCounter or Plausible can be added as a single script tag.
- **Dark/light toggle** — the shell is dark and articles are bone by design. A toggle would fight the design rather than serve it.
- **Multi-language** — see decision 5.
- **Live GitHub API data** — see §3.6.
- **PDF CV file** — replaced by the print stylesheet on `/cv/`.
- **Custom domain** — `kovs705.github.io` root and a custom domain both remain available later. Moving from the subpath to either requires updating `baseurl` and re-running §11.
