# Codex Scanner Reliability Rebuild

**Date:** 2026-03-06
**Goal:** Strip down the app to a reliable core experience: scan pages, save to books, export PDF. Rebuild the ViewModel and Views while keeping proven services and data models.

## Problem

General instability across the app. The ViewModel has complex state management (683 lines, multiple @Published booleans that can desync) and the UI layer is heavy with custom styles, Metal shaders, and animations that add fragility without serving the core workflow.

## Approach: Incremental Strip-Down

Rewrite the ViewModel and all Views from scratch using native macOS controls. Keep the service layer (CameraManager, ImageProcessor, PDFGenerator) and data models (Book, Page, CapturedPage) untouched.

## Architecture

### State Machine ViewModel

Replace the current bag of @Published booleans with an explicit enum-driven state machine:

```swift
enum ScannerState {
    case idle                          // Camera running, no detection
    case detecting(bounds: CGRect)     // Document detected, showing overlay
    case stabilizing(frames: Int)      // Counting stable frames for auto-capture
    case capturing                     // Photo being taken
    case reviewing(CapturedPage)       // User reviewing captured page
}
```

Impossible states become unrepresentable. Every transition is explicit.

### Services (kept as-is)

- **CameraManager** -- AVCaptureSession, Continuity Camera, device selection
- **ImageProcessor** -- Vision framework detection, CIImage processing, perspective correction
- **PDFGenerator** -- PDF creation from Book pages

### Data Models (kept as-is)

- **Book** -- SwiftData model, aggregate of pages
- **Page** -- Persistent page with image reference
- **CapturedPage** -- Transient page during scanning session
- **ScanningState** -- Enum: Stopped/Scanning/Paused
- **ScanningSettings** -- Observable settings singleton

## UI Design

### Principles

- Native macOS controls only (system Button, Toggle, Picker, List)
- No custom button styles, no Metal shaders, no particle effects
- No spring animations or custom transitions
- Standard AppKit/SwiftUI patterns

### Scanner View

- NSViewRepresentable camera preview
- System Toggle for auto-capture on/off
- System Picker for processing mode (Text/Photo/Mixed/Handwritten)
- System Picker for camera device selection
- Simple Rectangle stroke overlay for detected document bounds
- Standard Button for manual capture
- Native ScrollView with thumbnails for scanned pages

### Preview/Review View

- Shows captured image
- System controls for accept/retake
- Processing mode selector

### Library View

- List or LazyVGrid of books with native styling
- Click to view pages, drag-and-drop reorder
- Export button -> PDFGenerator -> NSSavePanel

## Capture Pipeline

1. Camera runs, frames sent to ImageProcessor for document detection
2. Document detected -> update overlay bounds on ViewModel state
3. Auto-capture on -> count stable frames (existing stability logic)
4. Capture trigger -> CameraManager.capturePhoto()
5. Process photo with selected mode (existing ImageProcessor pipeline)
6. Transition to .reviewing(page) state
7. User accepts -> save to current Book via SwiftData

### Removed from pipeline

- Bounds smoothing/interpolation
- Cooldown timer (state machine prevents double-capture)
- Bounds locking
- Orientation filtering

## File Changes

### Rewrite (new content, same path)

- ViewModels/ScannerViewModel.swift
- Views/ScannerView.swift
- Views/PreviewView.swift
- Views/ContentView.swift
- Views/LibraryView.swift
- Views/EditorView.swift
- Views/Components/DocumentBoundsOverlay.swift
- Views/Components/ScannedPagesStrip.swift
- Views/Components/CameraPreview.swift

### Delete

- Views/Components/NotionButtonStyles.swift
- Views/Components/NotionControlStyles.swift
- Views/Components/SolidToggleStyle.swift
- Views/Components/CaptureSuccessOverlay.swift
- Shaders/ParticleDissolve.metal

### Keep untouched

- Services/CameraManager.swift
- Services/ImageProcessor.swift
- Services/PDFGenerator.swift
- Models/Book.swift
- Models/Page.swift
- Models/CapturedPage.swift
- Models/ScanningState.swift
- Models/ScanningSettings.swift

## Success Criteria

- App launches and shows camera feed reliably
- Document detection overlay appears when document is in frame
- Auto-capture triggers after stable detection
- Manual capture works on button press
- Captured pages appear in thumbnail strip
- Pages can be saved to a book
- Books can be exported as PDF
- No crashes or freezes during normal scanning workflow
