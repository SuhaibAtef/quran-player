# `lib/features/`

One folder per top-level area of the app. Each feature folder owns its own UI, controllers, and state, and may depend on [`lib/domain/`](../domain/), [`lib/data/`](../data/), and [`lib/core/`](../core/). It must not depend on another feature's internals — cross-feature collaboration goes through `domain/` contracts or shared providers under [`lib/app/state/`](../app/state/).

The current top-level features match the IDEA.md MVP areas:

| Folder | Purpose | Foundation status |
|---|---|---|
| `home/` | Surah list landing | placeholder |
| `surah_detail/` | Single-surah reader | placeholder |
| `search/` | Quran search | placeholder |
| `bookmarks/` | Saved ayahs | placeholder |
| `settings/` | App preferences | theme selector wired in foundation |
| `mcp_status/` | Local MCP server status & toggles | placeholder |
