# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run in development
flutter run -d macos

# Build release app
flutter build macos
# Output: build/macos/Build/Products/Release/md Viewer.app

# Run all tests
flutter test

# Run a single test file
flutter test test/utils/markdown_splitter_test.dart

# Lint
flutter analyze
```

## Tests

Tests mirror `lib/` under `test/`:

| Test file | Covers |
|---|---|
| `test/models/markdown_file_test.dart` | `MarkdownFile` serialization, `copyWith`, bookmark round-trip |
| `test/services/file_service_test.dart` | `FileService` recent-files CRUD, `readFile`, `fileFromContent` |
| `test/utils/markdown_splitter_test.dart` | `MarkdownSplitter` segment splitting edge cases |

`file_service_test.dart` mocks the `com.jtsworkshop.mdViewer/file` MethodChannel via `TestDefaultBinaryMessengerBinding` — any new `FileService` tests that trigger native channel calls must register handlers in `setUp` and clear them in `tearDown`.

## Architecture

**md Viewer** is a macOS-only Flutter app (no iOS/Android/web targets). The Swift native layer and the Dart layer communicate over a single `MethodChannel` named `com.jtsworkshop.mdViewer/file`.

### Native ↔ Flutter channel (`AppDelegate.swift`)

The Swift side owns:
- **CLI / Finder file delivery** — CLI args are captured in `applicationDidFinishLaunching`, Finder "Open With" fires `application(_:open:)`. Both funnel into `deliver(_:)`, which either pushes the file immediately (if Flutter is already running) or stores it in `pendingFile` for `getInitialFile` to collect.
- **Security-scoped bookmarks** — `createBookmark` and `readWithBookmark` methods let the sandboxed app re-open files across sessions without holding a persistent entitlement.
- **Save panel** — `showSavePanel` wraps `NSSavePanel` so Dart can trigger a native save dialog.

On the Flutter side, `HomeScreen.initState` registers a `MethodCallHandler` on the same channel for `openFile` calls that arrive while the app is running, and calls `getInitialFile` on first frame to pick up anything buffered at launch.

### State management

No state management library is used. Theme state (`ThemeMode`) lives in `_MarkdownViewerAppState` and is passed to `HomeScreen` as a `ThemeMode` value + `VoidCallback`. File/sidebar/loading state lives in `_HomeScreenState`. Everything is plain `StatefulWidget`.

### Mermaid rendering

`MarkdownSplitter` splits a document into alternating `MarkdownSegment` chunks (`isMermaid: true/false`) by matching fenced code blocks tagged `mermaid`. `MarkdownViewerWidget` renders the document as a `ListView` of these segments — plain segments go to `flutter_markdown`'s `MarkdownBody`; mermaid segments go to `MermaidBlock`.

`MermaidBlock` uses a `WebViewController` loading an inline HTML page that pulls Mermaid.js from the CDN (`cdn.jsdelivr.net/npm/mermaid@11`). After render it reports the SVG height back to Dart via a `JavaScriptChannel` named `MermaidHeight`, which drives the widget's `AnimatedContainer` height.

### Export pipeline

`ExportFormat` is an abstract interface (`label`, `fileExtension`, `utTypes`, `skipSavePanel`, `generate`). `ExportService` holds the registry (`[PdfFormat, DocxFormat, PagesFormat]`) and orchestrates the save panel + file write. New formats are added by implementing `ExportFormat` and calling `ExportService.register`.

- **PDF** (`pdf_format.dart`) — pure-Dart via the `pdf` package. Walks the `markdown` AST directly. Uses `MermaidRenderer.renderToPng` (via `mermaid.ink` HTTP API) to embed mermaid diagrams as images. Handles non-Latin characters by splitting text runs between a monospace font and Arial Unicode MS.
- **DOCX** (`docx_format.dart`) — builds an OOXML `.zip` bundle using the `archive` package.
- **Pages** (`pages_format.dart`) — exports as DOCX to `Directory.systemTemp`, then calls `launchUrl` on the file URI to open it in Pages. `skipSavePanel` returns `true` so `ExportService` skips the save dialog for this format.

### Sandbox / entitlements

`Release.entitlements` enables the full App Sandbox (`app-sandbox = true`) with `files.user-selected.read-write` and `bookmarks.app-scope`. `DebugProfile.entitlements` disables the sandbox (`app-sandbox = false`) for easier local development. Security-scoped bookmarks are still created and stored in both configurations so the code path is always exercised.

`MarkdownFile.bookmarkData` (persisted in `SharedPreferences`) is the mechanism for cross-session reopens: `FileService.readFile` calls `readWithBookmark` when bookmark data is present, otherwise reads the file directly and creates a fresh bookmark for next time.