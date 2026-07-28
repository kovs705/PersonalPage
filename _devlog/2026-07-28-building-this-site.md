---
title: "Grain is doing most of the work"
date: 2026-07-28
tags: [css, design]
---

Spent the evening on the tactile feel of the shell and the finding is almost embarrassing: a single
inline SVG `feTurbulence` overlay — `mix-blend-mode:screen` at 6% opacity — accounts for most of what
reads as "physical."

The other half is press physics — one rule, applied everywhere:

```css
.btn:active{transform:translateY(1px);box-shadow:1px 1px 0 rgba(201,242,39,.28)}
```

Eighty milliseconds. That's the entire difference between a page and a panel of keys.
