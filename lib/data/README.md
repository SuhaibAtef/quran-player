# `lib/data/`

Data sources and repositories — Quran text, audio metadata, bookmark storage, MCP transport adapters. Currently empty; the first feature change to need a data source will populate this folder.

A repository here returns domain entities (from [`lib/domain/`](../domain/)) or `Result<T>`s, never raw HTTP / database rows.
