# linux/CLAUDE.md

Read alongside the [root CLAUDE.md](../CLAUDE.md). This file holds Linux-specific notes.

## Identity

- Executable name (`BINARY_NAME`) is `quran_player` and `APPLICATION_ID` is the placeholder `com.example.quran_player` ([CMakeLists.txt:7-10](CMakeLists.txt#L7-L10)). The application id must be a **valid reverse-DNS GTK app id** before release — see https://wiki.gnome.org/HowDoI/ChooseApplicationID.

## Build dependencies

- Requires `gtk+-3.0` headers on the build host (`pkg-config gtk+-3.0` resolves via [CMakeLists.txt:55](CMakeLists.txt#L55)). On Debian/Ubuntu: `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev`.
- Compiler warnings are treated as errors (`-Wall -Werror`); fix warnings, don't suppress them.

## Runtime dependencies

- `sqflite_common_ffi` requires the SQLite shared library at runtime. Most modern desktop distributions ship `libsqlite3` by default; if the user hits "library 'sqlite3' not found" on launch, install `libsqlite3-0` (Debian/Ubuntu) or `sqlite-libs` (Fedora/Arch). The Quran data layer surfaces this via `Failure.dataAccess` and the data-integrity error screen rather than crashing.

## Build

- `flutter build linux` produces a relocatable bundle in `build/linux/<arch>/release/bundle/`. Ship the whole directory together — the executable expects `lib/` and `data/` next to it.

## Distribution

- No `.desktop` file, AppImage, or Flatpak manifest is wired up yet. Document that workflow here when it lands.
