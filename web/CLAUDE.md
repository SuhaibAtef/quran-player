# web/CLAUDE.md

Read alongside the [root CLAUDE.md](../CLAUDE.md). This file holds web-specific notes.

## Identity

- [manifest.json](manifest.json) still has scaffold placeholders: `name`/`short_name` are `quran_player`, `description` is `"A new Flutter project."`, and `theme_color`/`background_color` are Flutter blue (`#0175C2`). Replace before deploying anywhere public.
- [index.html](index.html) carries the `<title>` and meta tags — update in the same change as `manifest.json`.

## Build & serve

- `flutter build web` outputs to `build/web/`. The site is a static bundle — host on any static server (Cloudflare Pages, GitHub Pages, etc.).
- `--base-href "/quran-player/"` is required if hosting under a subpath (e.g. GitHub Pages project site). Bake this into the `just build web` recipe in the root [Justfile](../Justfile) once a hosting target is chosen.

## Assets

- Recitation audio files are typically large; do **not** bundle them into the web build. Stream from a CDN and gate on `kIsWeb` for any plugin that lacks web support.
