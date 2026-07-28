# Build progress — personal site

**Updated:** 2026-07-28
**Branch:** `build-site` (never implement on `main`)
**Spec:** [specs/2026-07-27-personal-site-design.md](specs/2026-07-27-personal-site-design.md)
**Plan:** [plans/2026-07-28-personal-site.md](plans/2026-07-28-personal-site.md) — 18 tasks

## How to resume

Re-enter subagent-driven execution from **Task 4**. Per task: dispatch an implementer with the
task's full text pasted in (do not make the subagent read the plan), then a spec-compliance
reviewer, then a code-quality reviewer, fixing and re-reviewing until both pass.

## Status

| Task | State |
|---|---|
| 1. Build harness & config | ✅ Done, reviewed |
| 2. Content validation guard | ✅ Done, reviewed — 11/11 own tests pass |
| 3. Self-hosted fonts | ✅ Done, reviewed |
| 4. Design tokens & tactility CSS | ✅ Done, reviewed |
| 5. Base layout, head, header, footer | ✅ Done, reviewed — Lighthouse 98 perf / 100 a11y |
| 6. Projects collection content | ✅ Done, reviewed |
| 7. Project layout & projects index | ✅ Done, reviewed |
| 8. Homepage | ✅ Done, reviewed — Lighthouse 99 perf / 100 a11y |
| 9. Article reading surface | ✅ Done, reviewed |
| 10. Seed content | ✅ Done, reviewed |
| 11. Writing & devlog indexes | ✅ Done, reviewed |
| 12. Clack, copy, tilt JS | ✅ Done — 2583 bytes minified against a 4KB budget |
| 13. About page | ✅ Done |
| 14. CV page & print stylesheet | ⚠️ Built, **blocked on owner** — employment dates/employers |
| 15. Tags page & 404 | ✅ Done |
| 16. Hand-written Atom feed | ✅ Done — validates, both collections present |
| 17. Authoring tools & analytics | ✅ Done — GoatCounter code still to be supplied |
| 18. Deploy & full verification | ⬜ **Blocked** — needs owner (see below) |

All eleven routes plus `/feed.xml` and `/sitemap.xml` build locally.

Live check: `tools/build.sh` then serve `_site/` under a `/PersonalPage/` prefix (paths are
baseurl-absolute, so a root-served copy renders unstyled). `tools/serve.sh` does this for you at
http://localhost:4000/PersonalPage/.

**Beware stale CSS when verifying in a browser.** Two separate agents were misled by a cached
`site.css` and briefly believed new rules had not applied. Bypass with a cache-busting query or check
`getComputedStyle` rather than trusting a screenshot.

## What exists and works

- `tools/build.sh` — Docker-based production-parity Jekyll build, ~1s warm. **Host Ruby cannot
  run Jekyll 3.10** (system Ruby is 2.6, Homebrew Ruby is 4.0.5), so Docker is not optional.
- `tools/serve.sh` — live preview at `http://localhost:4000/PersonalPage/`, TTY-conditional.
- `tools/_docker-preamble.sh` — shared container preamble sourced by both wrappers.
- `tools/assert.sh` — `assert.sh "<desc>" '<regex>' <file>`; the project's test mechanism.
- `tools/validate-content.sh` + `tools/test-validate.sh` — content guard, 11/11 tests passing.
- `tools/fetch-fonts.sh` — fetches 5 WOFF2 files, fails loudly on a partial set.
- `_config.yml`, `Gemfile`, `Gemfile.lock`, `index.html` (placeholder), `assets/css/fonts.css`,
  `assets/fonts/*.woff2` (5 files, 484KB).

## Carry-forward corrections — the plan text is authoritative, these are why

Reviews found 12 real defects across the first three tasks. The plan has been updated to match
the shipped code, so implementers should follow the plan as written. Two items still need
attention when their tasks come up:

1. **`index.md` is now `index.html`.** Kramdown silently escaped `<!doctype html>` and `<html>`
   into visible literal text inside a `.md` file while `jekyll build` reported success. **Task 5
   and Task 8 say "replace `index.md`" — the file to edit is `index.html`.**
2. **Cabinet Grotesk is not downloaded.** Fontshare has no stable URL, so
   `assets/fonts/CabinetGrotesk-Extrabold.woff2` is absent by design and display headings fall
   back to `system-ui` 800. To fix it manually: download the family from
   <https://www.fontshare.com/fonts/cabinet-grotesk> and copy the 800 weight woff2 to that path.
   Nothing is blocked by leaving it.

## Task 18 is blocked on three owner decisions

1. **CV employment dates and employers** — `cv.md` carries two
   `**Role dates to be filled in by owner.**` markers. A `grep` guard in Task 14 Step 7 deliberately
   fails while they are present, blocking deploy. "Healthcare startup (NDA)" is a fine substitute if a
   company cannot be named.
2. **GoatCounter code** (optional) — register at <https://www.goatcounter.com>, then set
   `goatcounter: "<code>"` in `_config.yml`. Empty disables analytics cleanly; nothing breaks.
3. **Making the site public** — Task 18 pushes `build-site`, merges to `main`, and enables GitHub Pages.
   That publishes the site, so it needs the owner's explicit go-ahead rather than being done
   automatically.

## Owner action still required

**`cv.md` (Task 14) needs real employment dates and employers.** Nothing in the repo, the GitHub
profile, or PVresume states them. Task 14 Step 6 blocks deploy until the
`**Role dates to be filled in by owner.**` markers are replaced; "healthcare startup (NDA)" is a
fine substitute if a company cannot be named.

**GoatCounter code (Task 17)** — register at <https://www.goatcounter.com> and set
`goatcounter: "<code>"` in `_config.yml`. Leaving it `""` disables analytics; nothing breaks.

## Rules that will bite whoever continues

- Every internal path goes through `{{ '/x' | relative_url }}`. The site is served from
  `/PersonalPage`, so a bare `/writing/` 404s in production. `validate-content.sh` guards this.
- Quote every `title:`. An unquoted colon breaks the YAML and fails the build.
- `_articles` and `_devlog` files need an explicit `date:` — collections do not read it from the
  filename the way `_posts` does.
- `repository:` must stay in `_config.yml` or the build fails with `No repo name found`.
- Scroll-reveal elements must default to **visible**; the animation only enhances, inside
  `@supports (animation-timeline: view())`. Hidden-by-default renders a blank page on
  unsupported browsers, and the failure is silent.
