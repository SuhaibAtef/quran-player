# IDEA.md

## Project Idea

Build a desktop Quran Player using Flutter that provides a clean, respectful, and reliable way to read and listen to the Quran.

The app will also expose a local MCP server so approved AI clients can interact with the Quran Player through structured tools and resources. The MCP server will allow external AI assistants to search Quran data, retrieve surahs and ayahs, list reciters, and eventually control playback through safe, user-approved commands.

## Product Name

Quran Companion

##  Core Vision 

The goal is to create a modern desktop Quran application that combines:

* Accurate Quran text.
* High-quality audio playback.
* A calm and readable desktop interface.
* Local-first privacy.
* Safe MCP integration for AI-assisted Quran navigation and playback.

The app should not be a generic AI religious assistant. It should be a Quran Player first, with MCP as a controlled integration layer.

## Target Platforms

Initial target:

```text
Windows desktop
```

Later targets:

```text
macOS
Linux
```

## Primary Users

The app is intended for:

* Muslims who want a clean desktop Quran player.
* Students memorizing Quran.
* Users who want offline or focused Quran listening.
* Developers and AI users who want a local Quran MCP server.
* People who want AI clients to safely interact with Quran data without relying on random online sources.

## Main Problem

Most Quran apps are either mobile-first, web-first, or not designed for desktop workflows.

AI tools can answer Quran-related questions, but they often depend on general model knowledge and may hallucinate references, ayah numbers, or content. This project solves that by providing a local, structured, verified Quran data source through MCP.

## Proposed Solution

Create a Flutter desktop app with two connected parts:

```text
1. Quran Player desktop app
2. Local Quran MCP server
```

The Flutter app handles the user interface, Quran reading experience, audio playback, bookmarks, settings, and local storage.

The MCP server exposes selected app data and safe app commands to external AI clients.

## High-Level Architecture

```text
Flutter Desktop App
  - Quran reader UI
  - Audio player
  - Search
  - Bookmarks
  - Settings
  - MCP status screen

Shared Packages
  - Quran models
  - Quran database access
  - Audio metadata
  - MCP contracts and schemas

Local MCP Server
  - Quran resources
  - Quran tools
  - Playback tools
  - Permission checks
  - Audit logs
```

## Core App Features

### MVP Features

The first version should include:

* Desktop Flutter app.
* Surah list.
* Ayah display.
* Arabic Quran text.
* One reciter.
* Audio streaming.
* Play, pause, seek, next, previous.
* Basic Quran search.
* Bookmarks.
* Source attribution.
* Local read-only MCP server.

### V1 Features

After the MVP, add:

* Multiple reciters.
* Offline audio downloads.
* Verse-by-verse playback.
* Repeat ayah, surah, or range.
* Playback speed control.
* Search improvements.
* Translation support, only with verified licensing.
* MCP playback controls.
* MCP bookmark tools.
* In-app MCP audit log.
* Desktop packaging for Windows, macOS, and Linux.

## MCP Purpose

The MCP server exists so external AI clients can interact with the Quran Player in a controlled way.

Example use cases:

* “Find ayahs that mention patience.”
* “Open Surah Al-Kahf.”
* “Get Ayah 2:255.”
* “List available reciters.”
* “Play Surah Yasin with the selected reciter.”
* “Show my Quran bookmarks.”
* "Change Reciter to X" 

The MCP layer should never modify Quran text, invent references, or execute arbitrary system commands.

## MCP Server Design

The MCP server should be a local sidecar process.

```text
AI Client
  ↕ MCP protocol
Local Quran MCP Server
  ↕ local bridge
Flutter Quran Player
```

The server should support two modes:

### Mode A — Read-only data access

This works even when the app UI is not actively playing audio.

Supported tools:

```text
search_quran
get_ayah
get_surah
list_surahs
list_reciters
```

Supported resources:

```text
quran://metadata
quran://surahs
quran://surah/{surah}
quran://ayah/{surah}/{ayah}
quran://reciters
```

### Mode B — Playback control (Important)

This requires the Flutter app to be running.

Supported tools:

```text
play_surah
play_ayah
pause_playback
resume_playback
stop_playback
set_repeat
```

Playback commands must require user permission.

## Safety Rules

The project must follow these rules:

* Quran text must be preserved exactly as sourced.
* Quran references must never be invented.
* Translations and tafsir must only be added with clear licensing and attribution.
* MCP must be disabled or read-only by default.
* Playback control through MCP must require user approval.
* The app must not expose remote MCP access in the MVP.
* The MCP server must not allow arbitrary file access.
* The MCP server must not allow shell command execution.
* Secrets must not be stored in the Flutter client.
* All MCP inputs must be validated with strict schemas.

## Data Policy

The app should use verified Quran text sources only.

Data integrity checks should validate:

* 114 surahs.
* Correct ayah counts.
* Stable text checksums.
* No missing ayahs.
* No duplicate ayah keys.
* Correct surah and ayah numbering.
* Consistent MCP output with app database output.

Source attribution must be visible inside the app.

## Audio Policy

Audio sources must be used only when their usage terms allow it.

The app should store audio metadata such as:

```text
reciter_id
reciter_name
surah_number
ayah_number
audio_url
duration_ms
source
license_or_terms
```

The MVP can start with streaming audio. Offline downloads can come later.

The preferred workflow is:

```text
Linear issue
  -> OpenSpec proposal
  -> GitHub branch
  -> implementation
  -> tests
  -> pull request
  -> review
  -> merge
```

Every major feature should have:

* A Linear issue.
* An OpenSpec proposal.
* Acceptance criteria.
* Tests.
* A linked GitHub pull request.

## MVP Scope

The MVP should include:

```text
Quran Player Desktop MVP
  - Windows desktop app
  - Surah list
  - Arabic ayah display
  - One reciter
  - Audio streaming
  - Play/pause/seek
  - Basic search
  - Bookmarks
  - Source attribution
  - Local read-only MCP server
```

MVP MCP tools:

```text
search_quran
get_ayah
get_surah
list_surahs
list_reciters
```

## Out of Scope for MVP

Do not include these in the MVP:

```text
Remote MCP access
Cloud accounts
Mobile apps
Tafsir
Complex AI religious explanations
Multi-user sync
Mac App Store release
Linux Snap release
Automatic religious rulings
```

## Project Principle

The app should remain trustworthy before it becomes powerful.

Accuracy, attribution, privacy, and respectful Quran handling are more important than adding many features quickly.
