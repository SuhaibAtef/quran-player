# tarteel_qul example

A minimal runnable demo of the [`tarteel_qul`](../) mushaf rendering engine.

It renders the engine's built-in `DemoMushafAssetSource` — an invented
three-page mini-layout drawn with a generated box-glyph stub font — so the
package runs **without downloading any QUL resource**. The demo shows page
navigation (`Previous` / `Next` buttons and swipe) and the `onAyahTap` event.

```bash
flutter run
```

A real consumer supplies its own `MushafAssetSource` backed by genuine QUL
layout, word-script, and per-page font data. See the package
[README](../README.md) for the `MushafAssetSource` contract.
