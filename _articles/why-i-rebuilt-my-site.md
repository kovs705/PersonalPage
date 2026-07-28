---
title: "Why I rebuilt my site around a devlog"
date: 2026-07-28
description: "My old resume page made claims. This one shows version numbers, dates, and the parts that fought back."
tags: [meta, writing]
---

My previous site told visitors I "think beyond ticket execution." It was true, and it was useless — a
claim with nothing behind it. Anyone can write that sentence.

So this version is built on a different rule: **every row on the homepage is a fact you can check.**
A version number, a licence, a date, a commit. If a sentence can't be verified, it doesn't belong on
the front page.

## What changed structurally

The devlog attaches to projects. Each entry carries an optional `project` field, so a three-sentence
note about a gesture conflict becomes part of a build history rather than disappearing into a
chronological feed.

{% include note.html type="info" body="This site is static — Jekyll on GitHub Pages, no build step I run locally. The whole publishing flow is one Markdown file and one `git push`." %}

## What I cut

Stat cards claiming "4 human languages studied." A three-language switcher wrapped around one page of
text. Stock 3D illustrations of a glossy phone. None of it survived the rule above.
