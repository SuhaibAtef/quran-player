# windows/CLAUDE.md

Read alongside the [root CLAUDE.md](../CLAUDE.md). This file holds Windows-specific notes.

## Identity

- Executable name (`BINARY_NAME`) is `quran_player` ([CMakeLists.txt:7](CMakeLists.txt#L7)). Changing it renames the `.exe` and the install bundle directory.
- Product/company metadata (CompanyName, FileDescription, ProductName, version) lives in [runner/Runner.rc](runner/Runner.rc). Update before distributing a build.
- Window title and class name are set in [runner/main.cpp](runner/main.cpp) / [runner/win32_window.cpp](runner/win32_window.cpp).

## Build

- `flutter build windows` produces `build/windows/x64/runner/Release/` with the `.exe` plus dependent DLLs and a `data/` folder. The whole directory must ship together.
- Toolchain: Visual Studio 2022 with the **"Desktop development with C++"** workload. Compiler warnings are treated as errors (`/W4 /WX` in [CMakeLists.txt:42](CMakeLists.txt#L42)).
- C++17 is the minimum standard.

## Distribution

- No installer is wired up. When that lands (MSIX, Inno Setup, etc.), document the build steps here.

## Foundation notes

- Windows is the MVP target. The app launches via `flutter run -d windows` (`just run`) and renders the ForUI shell at the default window size — no custom sizing or DPI handling is configured in [runner/main.cpp](runner/main.cpp) yet. Adjust there if a feature needs a minimum window size or initial dimensions.
- The desktop nav chrome ([lib/app/widgets/app_shell.dart](../lib/app/widgets/app_shell.dart)) switches to `FSidebar` at ≥768 wide; on Windows the default window is large enough that the sidebar is always shown.
