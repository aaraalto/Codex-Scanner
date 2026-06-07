# Codex Scanner — Initial Window Experience Redesign

**Date:** 2026-06-06
**Status:** Approved — ready for implementation planning
**Supersedes:** the *UI structure* of `docs/plans/2026-03-06-reliability-rebuild.md` (camera-first `TabView`). Adopts that plan's `ScannerPhase` state-machine ViewModel and simplified camera components.

## Goal

Rebuild the app around one deliberate question: **what should the window be the moment Codex Scanner opens, and how does every component serve that?** The current window mixes three competing idioms (a hardcoded Notion dark palette, iOS-camera metaphors, and a "macOS Tahoe" claim) and feels incoherent. We replace it with a single, coherent, **home-first, pure-system macOS** window that you push into and back out of.

This is a top-down redesign: the window's job is fixed first, then every component is designed to build it.

## Design Decisions (settled in brainstorming)

1. **The window's job is Home/Library-first.** Launch lands on a shelf of scanned books, not the camera.
2. **One window, push-in navigation.** "New Scan" and drilling into books happen by pushing within the same window, with a consistent `‹ back` gesture. No second window, no tab bar, no sheet for the scanner.
3. **Welcoming empty state.** First launch shows a guided hero — "Scan your first book," a 1-2-3 of how it works (prop iPhone → capture pages → export PDF), and the primary *New Scan* action.
4. **Populated home is a cover gallery.** Books shown as a grid of cover cards (first page = cover thumbnail). Drilling in: Library → Book (page grid) → Page (editor).
5. **Pure-system visual language.** The user's macOS accent color, SF Pro, standard materials and radii, system controls. No fixed brand color, no custom button styles. The system accent is reserved for the single primary action at each level; everything else stays quiet.

## Navigation Architecture

A single `NavigationStack` drives the whole window. A typed route enum models the push stack; `LibraryHomeView` is the root.

```swift
enum Route: Hashable {
    case book(Book)      // page grid for a book
    case page(Page)      // page editor
    case scan            // the scanner
}
```

Push stack:

```
LibraryHome (root)
├─ .scan            → ScannerView           (‹ Library)
└─ .book(book)      → BookDetailView        (‹ Library)
   └─ .page(page)   → PageEditorView        (‹ <book title>)
```

- The macOS back button (provided by `NavigationStack`) is the universal "out" gesture at every level.
- After the scanner saves a book, the stack pops to root and the new book is selected/scrolled into view on the shelf.
- The window keeps `WindowGroup` + `.defaultSize(width: 900, height: 650)`, `minWidth: 900, minHeight: 650`.

## Component Inventory

"Every component designed to build the window." Each component below lists its **purpose**, **inputs**, **dependencies**, and **how it serves the window**.

### Shell

- **AppShell / `ContentView`** — purpose: own the `NavigationStack` + `Route` path; host the root. Inputs: none (reads `@Query` books, `modelContext`). Depends on: all top-level views. Serves: the single-window push model.
- **`AppCommands`** — purpose: menu + keyboard commands. Inputs: a binding/action to trigger New Scan. Provides ⌘N → New Scan. Depends on: shell navigation. Serves: native macOS expectations.

### Home

- **`LibraryHomeView`** (root) — purpose: the landing window. Shows `EmptyLibraryView` when there are no books, else the cover gallery. Toolbar: primary *New Scan* button (`.borderedProminent`, accent), trailing. Inputs: `@Query` books, navigation actions. Serves: decision #1, #4.
- **`EmptyLibraryView`** — purpose: the welcoming first impression. A centered hero: title "Scan your first book," a 1-2-3 steps row, and a prominent *New Scan* button. Inputs: New Scan action. Serves: decision #3.
- **`BookCoverCard`** — purpose: one book on the shelf. First-page thumbnail as cover, title, page count. Tap → `.book(book)`. Context menu: Rename, Export PDF, Delete. Inputs: a `Book`, selection/nav callbacks. Depends on: `Page.image`. Serves: decision #4.

### Book & Page

- **`BookDetailView`** — purpose: the page grid for one book. Nav title = book title; toolbar: Rename, Export PDF. `LazyVGrid` of page thumbnails; tap → `.page(page)`. Context menu per page: Delete. (Drag-to-reorder: nice-to-have, included only if cheap.) Inputs: a `Book`. Depends on: `Book.sortedPages`, `PDFGenerator`. Serves: the push-in drill-down.
- **`PageThumbnailCard`** — purpose: one page in the grid. Image thumbnail + page number; selection ring uses accent. Inputs: a `Page`, selected flag. Serves: visual consistency with cover cards.
- **`PageEditorView`** — purpose: view/adjust a single page (rotate, filter presets). Pushed as the 3rd level. Back = `‹ <book title>`. Inputs: a `Page`. Depends on: `ImageProcessor` presets. Serves: editing without leaving the window.

### Scanner

- **`ScannerView`** — purpose: the clean camera-first capture experience. Full-bleed camera with bounds overlay, an over-video controls bar, and the captured-pages strip. Back = `‹ Library`; leaving with unsaved pages prompts a confirm. A *Save to Book* action creates/append. Inputs: none (owns `ScannerViewModel`). Depends on: the components below + ViewModel. Serves: decision #2 (push-in scanner), "A built cleanly."
- **`ScannerViewModel`** — purpose: the capture state machine. Single `@Published phase: ScannerPhase` (`idle / scanning / capturing / processing`) instead of many booleans. Owns `capturedPages`, processing mode, save-to-book. Adopted from the reliability-rebuild plan. Depends on: `CameraManager`, `ImageProcessor`.
- **`CameraPreview`** (`NSViewRepresentable`) — purpose: render the `AVCaptureSession`. Simplified (no scroll-zoom). Reused from reliability-rebuild plan.
- **`DocumentBoundsOverlay`** — purpose: draw detected document bounds over video. **Reuse and refine** the existing strong Canvas-based implementation; restyle to the fixed `scanner*` over-video tokens. Inputs: `DocumentBounds`, view size.
- **`CaptureControls`** — purpose: the over-video control bar. Capture/shutter button (system photo-shutter, not a red record dot), auto-capture toggle, camera-device picker, processing-mode picker. Uses fixed `scanner*` tokens so it stays legible on video. Serves: dropping iOS-camera idioms.
- **`ScannedPagesStrip`** — purpose: horizontal strip of captured-page thumbnails with per-page delete. Inputs: `[CapturedPage]`, delete callback. Reused/simplified from reliability-rebuild plan.
- **Save-to-Book flow** — purpose: name a new book or pick an existing one, then save captured pages and pop to Home. Implemented as a sheet from the scanner. Depends on: `@Query` books, `ScannerViewModel.saveToBook`.

### Foundation

- **`Theme.swift`** — purpose: the single token source (Spacing, Radius, Typography, Motion, semantic colors, fixed `scanner*` over-video colors). **Resolved to pure-system:** `appAccent = .accentColor`; the placeholder brand indigo (`appBrand`, `appAccentHover`) is no longer used by the window and may be removed. Chrome typography moves toward semantic system text styles (`.title2`, `.headline`, `.body`, `.callout`, `.caption`); over-video badges keep fixed sizes for legibility.
- **Deletions** — the hand-rolled styles are removed in favor of system controls: `NotionButtonStyles`, `NotionControlStyles`, `SolidToggleStyle`, `CaptureSuccessOverlay`, and any remaining Notion/iOS-camera artifacts (red record button, yellow zoom, 3s auto-hide).

## Kept Untouched

- **Services:** `CameraManager`, `ImageProcessor`, `PDFGenerator`.
- **Models:** `Book`, `Page`, `CapturedPage`, `ScanningSettings`. (`ScanningState` is superseded by `ScannerPhase` and removed if unreferenced.)

## Data Flow

1. Launch → `ContentView` builds `NavigationStack`; `LibraryHomeView` reads books via `@Query`.
2. No books → `EmptyLibraryView`. Books → cover gallery.
3. *New Scan* (toolbar / ⌘N / empty-state button) pushes `.scan`.
4. Scanner runs `CameraManager`; frames → `ImageProcessor.detectDocument`; `ScannerViewModel` advances `phase`; stable detection or manual press → capture → process → append to `capturedPages`.
5. *Save to Book* → write images via `ImageProcessor.save`, create/append a `Book` with `Page`s, `modelContext.save()`, clear captured pages, pop to Home.
6. New book appears on the shelf. Drill in: `.book(book)` → page grid → `.page(page)` → editor.
7. Export: `BookDetailView` / cover context menu → `PDFGenerator` → `NSSavePanel`.

## Visual Language Rules (pure system)

- **Accent:** `Color.accentColor` (the user's system accent). Reserved for the single primary action at each level (New Scan, capture, save). Never for decoration.
- **Type:** SF Pro via semantic system text styles for chrome; fixed sizes only for over-video badges.
- **Surfaces:** system materials (`.bar`, `.regularMaterial`) and semantic colors (`windowBackgroundColor`, `controlBackgroundColor`, label colors). No hardcoded hex in chrome.
- **Controls:** system `Button`, `Toggle(.switch)`, `Picker(.menu)`, `.roundedBorder` text fields. No custom button styles.
- **Radii/spacing:** from `Theme.Radius` / `Theme.Spacing`, `.continuous` corners.
- **Over-video chrome:** fixed `scanner*` tokens (white frame, black scrim) so it stays legible regardless of appearance.

## Success Criteria

- App launches into **Home**, not the camera.
- Empty library shows the welcoming guided hero with a working *New Scan*.
- *New Scan* (button and ⌘N) pushes into a clean camera-first scanner with a `‹ Library` back.
- Capture (auto + manual) works; captured pages appear in the strip; Save to Book creates/append and pops to Home with the new book visible.
- Cover gallery shows books; drilling Library → Book → Page works with consistent back navigation; the editor adjusts a page.
- Export PDF produces a valid file.
- No `Notion*`/`SolidToggle` custom styles remain; no red record button / yellow zoom / auto-hide. Chrome adapts to Light/Dark and the system accent.
- Builds with 0 warnings / 0 errors; app launches without crash.

## Resolved for v1

1. **Drag-to-reorder pages** in `BookDetailView` — **deferred.** Pages stay ordered by `Page.order`; reorder UI comes later. The model already supports it, so it's cheap to add.
2. **Editor scope** — **minimal:** rotate (left/right) + filter presets, matching the existing `EditorView` capabilities.
3. **Cover thumbnail** — **always the first page.** User-pickable covers are out of scope for v1.
4. **New Scan target** — **always starts a fresh capture session.** The new-vs-existing-book choice happens in the Save-to-Book flow, which already covers "append to an existing book." No separate "scan into this book" entry point in v1.

## Out of Scope (YAGNI for now)

- Liquid Glass / custom materials beyond system.
- Onboarding screens beyond the empty-state hero.
- Multi-window / multi-display scanner.
- iCloud sync, search, tags, collections.
