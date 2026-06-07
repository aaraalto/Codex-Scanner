# Initial Window Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Codex Scanner as a home-first, single-window, pure-system macOS app: launch into a book library (welcoming empty state → cover gallery), push into a clean camera-first scanner, and drill Library → Book → Page.

**Architecture:** A single `NavigationStack` driven by a typed `Route` enum is the whole window. New screens/components are built alongside the existing app, the shell is switched over in one task, then the old files are deleted — so the project compiles after every task. Services (`CameraManager`, `ImageProcessor`, `PDFGenerator`) and SwiftData models (`Book`, `Page`, `CapturedPage`) are kept untouched; the scanner ViewModel is rebuilt as an enum-driven `ScannerPhase` state machine.

**Tech Stack:** SwiftUI, SwiftData, AVFoundation, Vision, CoreImage, PDFKit, AppKit. Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`). No new dependencies.

---

## Verification Strategy (read first)

This is a SwiftUI/AppKit app. Two kinds of verification are used, chosen honestly per task:

- **Logic (TDD):** `Route`, `Book.coverPage`, and `ScannerModel` page-management have real Swift Testing unit tests written test-first.
- **Views (build + preview + smoke):** SwiftUI view layout is not unit-testable here (no snapshot infra, and adding it is out of scope). View tasks are verified by a clean **build**, a compiling **`#Preview`**, and a final manual **smoke test** in Task 15.

### Project facts

- **Scheme:** `Codex Scanner`. **Test target:** `Codex ScannerTests` (Swift Testing). **App module name:** `Codex_Scanner`.
- The Xcode project uses **file-system-synchronized root groups** for `Codex Scanner/`, `Codex ScannerTests/`, `Codex ScannerUITests/`. **Any new `.swift` file (or subfolder) placed under those folders is automatically compiled** — no `project.pbxproj` edits needed.
- Build with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and aim for **0 warnings**.

### Standard commands

- **Build:**
  ```bash
  cd "/Users/aaraalto/Developer/02 MacOS/Codex Scanner"
  xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20
  ```
  Expected: `** BUILD SUCCEEDED **`
- **Test:**
  ```bash
  cd "/Users/aaraalto/Developer/02 MacOS/Codex Scanner"
  xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30
  ```
  Expected: `** TEST SUCCEEDED **`
  (If it reports no tests ran, edit the `Codex Scanner` scheme → Test action → add the `Codex ScannerTests` target, then re-run.)

All work happens on the existing branch `redesign/initial-window`.

---

## File Structure

**New files (auto-included via synchronized groups):**

| Path | Responsibility |
|---|---|
| `Codex Scanner/Navigation/Route.swift` | `Route` enum + `FocusedValues.navigationPath` for the nav stack |
| `Codex Scanner/ViewModels/ScannerModel.swift` | Enum-driven scanner state machine (`ScannerPhase`) |
| `Codex Scanner/Views/Scanner/DocumentFrameOverlay.swift` | Canvas overlay of detected document bounds (over-video tokens) |
| `Codex Scanner/Views/Scanner/CapturedPagesStrip.swift` | Horizontal strip of captured-page thumbnails |
| `Codex Scanner/Views/Scanner/CaptureControlsBar.swift` | Over-video controls: shutter, auto toggle, mode + camera pickers |
| `Codex Scanner/Views/Scanner/ScannerScreen.swift` | The camera-first scanner screen + save-to-book sheet |
| `Codex Scanner/Views/Library/EmptyLibraryView.swift` | Welcoming guided empty state |
| `Codex Scanner/Views/Library/BookCoverCard.swift` | One book on the shelf (cover, title, count) |
| `Codex Scanner/Views/Library/PageGridCell.swift` | One page thumbnail in a book |
| `Codex Scanner/Views/Library/PageEditorScreen.swift` | Page editor (rotate + filter presets) |
| `Codex Scanner/Views/Library/BookDetailView.swift` | Page grid for one book + rename/export |
| `Codex Scanner/Views/Library/LibraryHomeView.swift` | Root: empty state vs cover gallery + New Scan |
| `Codex ScannerTests/RouteTests.swift` | Tests for `Route` |
| `Codex ScannerTests/BookCoverTests.swift` | Tests for `Book.coverPage` |
| `Codex ScannerTests/ScannerModelTests.swift` | Tests for `ScannerModel` page management |

**Modified:** `Codex Scanner/Models/Book.swift` (add `coverPage`), `Codex Scanner/ContentView.swift` (Task 14), `Codex Scanner/AppCommands.swift` (Task 14), `Codex Scanner/Codex_ScannerApp.swift` (Task 14).

**Deleted (Task 15):** old `ScannerView.swift`, `ScannerViewModel.swift`, `LibraryView.swift`, `EditorView.swift`, `PreviewView.swift`, `Models/ScanningState.swift`, and components `NotionButtonStyles`, `NotionControlStyles`, `SolidToggleStyle`, `CaptureSuccessOverlay`, `DocumentBoundsOverlay`, `ScannedPagesStrip`, `PageThumbnail`, `ScanThumbnail`, `PreviewThumbnail`, `CameraSelector`, `CapturedPageRow`, `ProcessingModeSelector`.

**Kept untouched:** `Services/*`, `Models/Book|Page|CapturedPage|ScanningSettings.swift`, `DesignSystem/Theme.swift` (already pure-system: `appAccent = .accentColor`), `Views/Components/CameraPreview.swift` (reused), `Views/Extensions/Color+Hex.swift`, `Views/Extensions/NSImage+Resize.swift`.

---

### Task 1: Navigation Route

Defines the typed navigation route and a focused value so menu commands can push onto the stack. Pure value type — TDD.

**Files:**
- Create: `Codex Scanner/Navigation/Route.swift`
- Test: `Codex ScannerTests/RouteTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Codex ScannerTests/RouteTests.swift`:

```swift
import Testing
@testable import Codex_Scanner

struct RouteTests {
    @Test func scanEqualsScan() {
        #expect(Route.scan == Route.scan)
    }

    @Test func scanNotEqualBook() {
        let book = Book(title: "A")
        #expect(Route.scan != Route.book(book))
    }

    @Test func differentBooksAreNotEqual() {
        let a = Book(title: "A")
        let b = Book(title: "B")
        #expect(Route.book(a) != Route.book(b))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: FAIL — build error "cannot find 'Route' in scope".

- [ ] **Step 3: Create the Route type**

Create `Codex Scanner/Navigation/Route.swift`:

```swift
//
//  Route.swift
//  Codex Scanner
//
//  Typed navigation routes for the single-window NavigationStack.
//

import SwiftUI

/// One destination on the navigation stack. The library is the root, so it is
/// not represented here — only what you can push onto it.
enum Route: Hashable {
    case book(Book)   // page grid for a book
    case page(Page)   // page editor
    case scan         // the scanner
}

/// Focused value carrying a binding to the navigation path, so menu commands
/// (e.g. File ▸ New Scan / ⌘N) can push routes without owning the path.
struct NavigationPathKey: FocusedValueKey {
    typealias Value = Binding<[Route]>
}

extension FocusedValues {
    var navigationPath: Binding<[Route]>? {
        get { self[NavigationPathKey.self] }
        set { self[NavigationPathKey.self] = newValue }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Codex Scanner/Navigation/Route.swift" "Codex ScannerTests/RouteTests.swift"
git commit -m "Add typed Route + navigationPath focused value

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Book cover helper

`BookCoverCard` needs the book's cover image — the first page in order. Add a tested helper.

**Files:**
- Modify: `Codex Scanner/Models/Book.swift`
- Test: `Codex ScannerTests/BookCoverTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Codex ScannerTests/BookCoverTests.swift`:

```swift
import Testing
@testable import Codex_Scanner

struct BookCoverTests {
    @Test func emptyBookHasNoCover() {
        let book = Book(title: "Empty")
        #expect(book.coverPage == nil)
    }

    @Test func coverIsFirstPageInOrder() {
        let book = Book(title: "Three")
        let p0 = Page(imagePath: "a.jpg", order: 2)
        let p1 = Page(imagePath: "b.jpg", order: 0)
        let p2 = Page(imagePath: "c.jpg", order: 1)
        book.pages = [p0, p1, p2]
        #expect(book.coverPage?.imagePath == "b.jpg")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: FAIL — "value of type 'Book' has no member 'coverPage'".

- [ ] **Step 3: Add the helper**

In `Codex Scanner/Models/Book.swift`, add this computed property inside the `Book` class, right after the existing `var pageCount: Int { pages.count }`:

```swift
    /// The page used as the book's cover thumbnail (first page in reading order).
    var coverPage: Page? {
        sortedPages.first
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Codex Scanner/Models/Book.swift" "Codex ScannerTests/BookCoverTests.swift"
git commit -m "Add Book.coverPage (first page in order)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: ScannerModel state machine

Rebuild the scanner ViewModel as a clean `ScannerPhase` state machine in a **new** file (`ScannerModel`) so the old `ScannerViewModel` keeps compiling until Task 15. Page-management is TDD.

**Files:**
- Create: `Codex Scanner/ViewModels/ScannerModel.swift`
- Test: `Codex ScannerTests/ScannerModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Codex ScannerTests/ScannerModelTests.swift`:

```swift
import Testing
import CoreImage
@testable import Codex_Scanner

@MainActor
struct ScannerModelTests {
    private func makeCapturedPage() -> CapturedPage {
        let image = CIImage(color: .gray).cropped(to: CGRect(x: 0, y: 0, width: 10, height: 10))
        return CapturedPage(
            originalImage: image,
            processedImage: image,
            bounds: nil,
            preset: .original,
            processingMode: .mixed,
            thumbnail: nil
        )
    }

    @Test func startsIdle() {
        let model = ScannerModel()
        #expect(model.phase == .idle)
    }

    @Test func removePageRemovesMatch() {
        let model = ScannerModel()
        let a = makeCapturedPage()
        let b = makeCapturedPage()
        model.capturedPages = [a, b]
        model.removePage(a)
        #expect(model.capturedPages.count == 1)
        #expect(model.capturedPages.first?.id == b.id)
    }

    @Test func clearAllPagesEmptiesList() {
        let model = ScannerModel()
        model.capturedPages = [makeCapturedPage(), makeCapturedPage()]
        model.clearAllPages()
        #expect(model.capturedPages.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: FAIL — "cannot find 'ScannerModel' in scope".

- [ ] **Step 3: Create ScannerModel**

Create `Codex Scanner/ViewModels/ScannerModel.swift`:

```swift
//
//  ScannerModel.swift
//  Codex Scanner
//
//  Enum-driven scanner state machine. Replaces the many-boolean
//  ScannerViewModel with a single ScannerPhase.
//

import SwiftUI
import SwiftData
import Combine
import CoreImage
import AppKit

/// The scanner's current operational phase.
enum ScannerPhase: Equatable {
    case idle        // camera off / not scanning
    case scanning    // looking for documents
    case capturing   // a photo is being taken
    case processing  // a captured photo is being processed
}

@MainActor
final class ScannerModel: ObservableObject {

    // MARK: - Published state
    @Published var phase: ScannerPhase = .idle
    @Published var isAutoCaptureEnabled = true
    @Published var detectedBounds: ImageProcessor.DocumentBounds?
    @Published var capturedPages: [CapturedPage] = []
    @Published var processingMode: ImageProcessor.ProcessingMode = .mixed
    @Published var exportQuality: ImageProcessor.ExportQuality = .high
    @Published var errorMessage: String?

    // MARK: - Services
    let cameraManager = CameraManager()
    let imageProcessor = ImageProcessor()

    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private var previousBounds: ImageProcessor.DocumentBounds?
    private var stableFrameCount = 0
    private let stabilityThreshold = 25
    private let movementThreshold: CGFloat = 0.015

    init() {
        setupBindings()
    }

    // MARK: - Lifecycle
    func initializeCamera() async {
        await cameraManager.startSession()
        phase = .scanning
    }

    func stop() {
        cameraManager.stopSession()
        phase = .idle
        resetStability()
    }

    func capturePhoto() {
        guard phase == .scanning else { return }
        phase = .capturing
        cameraManager.capturePhoto()
    }

    // MARK: - Page management
    func removePage(_ page: CapturedPage) {
        capturedPages.removeAll { $0.id == page.id }
    }

    func clearAllPages() {
        capturedPages.removeAll()
    }

    func movePage(from source: IndexSet, to destination: Int) {
        capturedPages.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Save
    func saveToBook(_ book: Book, modelContext: ModelContext) async throws {
        let previous = phase
        phase = .processing
        defer { phase = previous }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookFolder = documentsURL.appendingPathComponent(book.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookFolder, withIntermediateDirectories: true)

        let ext = exportQuality == .maximum ? "png" : "jpg"
        for (index, captured) in capturedPages.enumerated() {
            let filename = "\(UUID().uuidString).\(ext)"
            let fileURL = bookFolder.appendingPathComponent(filename)
            let corrected = correctOrientation(captured.processedImage)
            try imageProcessor.save(image: corrected, to: fileURL, quality: exportQuality)
            let relativePath = "\(book.id.uuidString)/\(filename)"
            let page = Page(imagePath: relativePath, order: book.pageCount + index)
            book.addPage(page)
        }

        try modelContext.save()
        capturedPages.removeAll()
    }

    // MARK: - Private helpers
    private func correctOrientation(_ image: CIImage) -> CIImage {
        guard let value = image.properties[kCGImagePropertyOrientation as String] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: value) else {
            return image
        }
        return image.oriented(orientation)
    }

    private func resetStability() {
        stableFrameCount = 0
        previousBounds = nil
        detectedBounds = nil
    }

    private func setupBindings() {
        cameraManager.$error
            .compactMap { $0?.localizedDescription }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.errorMessage = message }
            .store(in: &cancellables)

        cameraManager.framePublisher
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.global(qos: .userInteractive), latest: true)
            .sink { [weak self] pixelBuffer in
                Task { @MainActor [weak self] in
                    guard let self, self.phase == .scanning else { return }
                    let processor = self.imageProcessor
                    let bounds = await Task.detached { processor.detectDocument(in: pixelBuffer) }.value
                    self.handleDetectedBounds(bounds)
                }
            }
            .store(in: &cancellables)

        cameraManager.photoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ciImage in
                Task { @MainActor in await self?.processPhoto(ciImage) }
            }
            .store(in: &cancellables)
    }

    private func handleDetectedBounds(_ bounds: ImageProcessor.DocumentBounds?) {
        guard phase == .scanning else { return }
        detectedBounds = bounds

        guard let newBounds = bounds else {
            previousBounds = nil
            stableFrameCount = 0
            return
        }

        if let old = previousBounds {
            let movement = maxCornerMovement(from: old, to: newBounds)
            if movement < movementThreshold {
                stableFrameCount += 1
                if isAutoCaptureEnabled && stableFrameCount >= stabilityThreshold {
                    stableFrameCount = 0
                    capturePhoto()
                }
            } else {
                stableFrameCount = max(0, stableFrameCount - 2)
            }
        }
        previousBounds = newBounds
    }

    private func maxCornerMovement(from old: ImageProcessor.DocumentBounds,
                                   to new: ImageProcessor.DocumentBounds) -> CGFloat {
        max(
            distance(old.topLeft, new.topLeft),
            distance(old.topRight, new.topRight),
            distance(old.bottomLeft, new.bottomLeft),
            distance(old.bottomRight, new.bottomRight)
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2))
    }

    private func processPhoto(_ ciImage: CIImage) async {
        phase = .processing
        defer {
            phase = .scanning
            resetStability()
        }

        let oriented = correctOrientation(ciImage)
        let bounds = detectedBounds ?? (await imageProcessor.detectDocument(in: oriented))
        let processed = imageProcessor.process(
            image: oriented,
            bounds: bounds,
            preset: .original,
            mode: processingMode,
            enhance: true
        )
        let thumbnail = imageProcessor.createHighResThumbnail(
            from: processed,
            size: NSSize(width: 150, height: 200)
        )
        let page = CapturedPage(
            originalImage: oriented,
            processedImage: processed,
            bounds: bounds,
            preset: .original,
            processingMode: processingMode,
            thumbnail: thumbnail
        )
        capturedPages.append(page)

        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Pop") {
            sound.play()
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Codex Scanner/ViewModels/ScannerModel.swift" "Codex ScannerTests/ScannerModelTests.swift"
git commit -m "Add ScannerModel state machine (ScannerPhase)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: DocumentFrameOverlay

New, simplified bounds overlay: Canvas mask + crisp frame + corner dots, using the fixed over-video tokens. No drag handles, no stability slider.

**Files:**
- Create: `Codex Scanner/Views/Scanner/DocumentFrameOverlay.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Scanner/DocumentFrameOverlay.swift`:

```swift
//
//  DocumentFrameOverlay.swift
//  Codex Scanner
//
//  Draws detected document bounds over the live camera feed.
//

import SwiftUI

struct DocumentFrameOverlay: View {
    let bounds: ImageProcessor.DocumentBounds
    let viewSize: CGSize

    var body: some View {
        Canvas { context, size in
            let tl = denormalize(bounds.topLeft, in: size)
            let tr = denormalize(bounds.topRight, in: size)
            let bl = denormalize(bounds.bottomLeft, in: size)
            let br = denormalize(bounds.bottomRight, in: size)

            var document = Path()
            document.move(to: tl)
            document.addLine(to: tr)
            document.addLine(to: br)
            document.addLine(to: bl)
            document.closeSubpath()

            // Dim everything outside the detected document.
            let full = Path(CGRect(origin: .zero, size: size))
            context.fill(full.subtracting(document), with: .color(Color.scannerScrim))

            // Crisp frame.
            context.stroke(document, with: .color(Color.scannerBorder), lineWidth: 1.5)

            // Corner dots.
            for point in [tl, tr, bl, br] {
                let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(Color.scannerHandle))
            }
        }
        .allowsHitTesting(false)
    }

    /// Vision coordinates are normalized with origin bottom-left; flip Y for the view.
    private func denormalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
    }
}

#Preview {
    DocumentFrameOverlay(
        bounds: ImageProcessor.DocumentBounds(
            topLeft: CGPoint(x: 0.12, y: 0.9),
            topRight: CGPoint(x: 0.88, y: 0.9),
            bottomLeft: CGPoint(x: 0.12, y: 0.1),
            bottomRight: CGPoint(x: 0.88, y: 0.1),
            confidence: 1
        ),
        viewSize: CGSize(width: 400, height: 300)
    )
    .frame(width: 400, height: 300)
    .background(.black)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Scanner/DocumentFrameOverlay.swift"
git commit -m "Add DocumentFrameOverlay (Canvas bounds over video)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: CapturedPagesStrip

New horizontal strip of captured-page thumbnails with a delete context menu.

**Files:**
- Create: `Codex Scanner/Views/Scanner/CapturedPagesStrip.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Scanner/CapturedPagesStrip.swift`:

```swift
//
//  CapturedPagesStrip.swift
//  Codex Scanner
//

import SwiftUI

struct CapturedPagesStrip: View {
    let pages: [CapturedPage]
    let onDelete: (CapturedPage) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    VStack(spacing: Theme.Spacing.xs) {
                        thumbnail(page)
                        Text("\(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            onDelete(page)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(height: 110)
        .background(.bar)
    }

    @ViewBuilder
    private func thumbnail(_ page: CapturedPage) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        if let thumb = page.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 80)
                .clipShape(shape)
                .overlay(shape.stroke(Color.appBorder, lineWidth: 0.5))
        } else {
            shape
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 60, height: 80)
        }
    }
}

#Preview {
    CapturedPagesStrip(pages: [], onDelete: { _ in })
        .frame(width: 500)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Scanner/CapturedPagesStrip.swift"
git commit -m "Add CapturedPagesStrip

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: CaptureControlsBar

New over-video control bar: photo-shutter capture button, auto-capture toggle, processing-mode picker, and a camera-device picker when more than one device is available.

**Files:**
- Create: `Codex Scanner/Views/Scanner/CaptureControlsBar.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Scanner/CaptureControlsBar.swift`:

```swift
//
//  CaptureControlsBar.swift
//  Codex Scanner
//

import SwiftUI
import AVFoundation

struct CaptureControlsBar: View {
    @ObservedObject var model: ScannerModel

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            captureButton

            Toggle("Auto", isOn: $model.isAutoCaptureEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.white)
                .foregroundStyle(.white)

            Picker("Mode", selection: $model.processingMode) {
                ForEach(ImageProcessor.ProcessingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 130)

            if model.cameraManager.availableDevices.count > 1 {
                Picker("Camera", selection: deviceBinding) {
                    ForEach(model.cameraManager.availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(Optional(device))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 170)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.scannerControlBackground)
    }

    private var captureButton: some View {
        Button {
            model.capturePhoto()
        } label: {
            ZStack {
                Circle().strokeBorder(.white.opacity(0.7), lineWidth: 3).frame(width: 46, height: 46)
                Circle().fill(.white).frame(width: 36, height: 36)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.phase != .scanning)
        .help("Capture page")
    }

    private var deviceBinding: Binding<AVCaptureDevice?> {
        Binding(
            get: { model.cameraManager.currentDevice },
            set: { device in
                if let device { Task { await model.cameraManager.switchDevice(to: device) } }
            }
        )
    }
}

#Preview {
    CaptureControlsBar(model: ScannerModel())
        .frame(width: 600)
        .background(.black)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Scanner/CaptureControlsBar.swift"
git commit -m "Add CaptureControlsBar (over-video controls)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: ScannerScreen

The camera-first scanner screen: camera stage + overlay + controls + captured strip, a custom `‹ Library` back with a discard confirmation when there are unsaved pages, and a Save-to-Book sheet (create new or append to existing). Reuses the existing `CameraPreview`.

**Files:**
- Create: `Codex Scanner/Views/Scanner/ScannerScreen.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Scanner/ScannerScreen.swift`:

```swift
//
//  ScannerScreen.swift
//  Codex Scanner
//
//  Camera-first scanning, pushed onto the library's navigation stack.
//

import SwiftUI
import SwiftData

struct ScannerScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ScannerModel()
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    @State private var showSaveSheet = false
    @State private var showDiscardConfirm = false
    @State private var newBookTitle = "Untitled Book"
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            cameraStage
            CaptureControlsBar(model: model)
            if !model.capturedPages.isEmpty {
                Divider()
                CapturedPagesStrip(pages: model.capturedPages, onDelete: { model.removePage($0) })
            }
        }
        .navigationTitle("Scan")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { attemptLeave() } label: {
                    Label("Library", systemImage: "chevron.backward")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save to Book…") { showSaveSheet = true }
                    .disabled(model.capturedPages.isEmpty || isSaving)
            }
        }
        .task { await model.initializeCamera() }
        .onDisappear { model.stop() }
        .alert("Camera Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog(
            "Discard \(model.capturedPages.count) captured page\(model.capturedPages.count == 1 ? "" : "s")?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Scanning", role: .cancel) {}
        }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
    }

    // MARK: - Camera stage
    private var cameraStage: some View {
        ZStack {
            CameraPreview(session: model.cameraManager.session)
            if let bounds = model.detectedBounds, model.phase == .scanning {
                GeometryReader { geo in
                    DocumentFrameOverlay(bounds: bounds, viewSize: geo.size)
                }
            }
            if model.phase == .processing {
                ProgressView()
                    .controlSize(.large)
                    .padding(Theme.Spacing.lg)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Save sheet
    private var saveSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Save \(model.capturedPages.count) Page\(model.capturedPages.count == 1 ? "" : "s")")
                .font(.headline)

            HStack {
                TextField("New book title", text: $newBookTitle)
                    .textFieldStyle(.roundedBorder)
                Button("Create & Save") {
                    let book = Book(title: newBookTitle.isEmpty ? "Untitled Book" : newBookTitle)
                    modelContext.insert(book)
                    save(to: book)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)
            }

            if !books.isEmpty {
                Divider()
                Text("Or add to an existing book")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                List(books) { book in
                    Button { save(to: book) } label: {
                        HStack {
                            Text(book.title)
                            Spacer()
                            Text("\(book.pageCount) page\(book.pageCount == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .frame(height: min(CGFloat(books.count) * 32 + 8, 200))
            }

            HStack {
                Spacer()
                Button("Cancel") { showSaveSheet = false }
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 420)
    }

    // MARK: - Actions
    private func attemptLeave() {
        if model.capturedPages.isEmpty {
            dismiss()
        } else {
            showDiscardConfirm = true
        }
    }

    private func save(to book: Book) {
        isSaving = true
        Task {
            do {
                try await model.saveToBook(book, modelContext: modelContext)
                showSaveSheet = false
                newBookTitle = "Untitled Book"
                dismiss()
            } catch {
                model.errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`
(If `navigationBarBackButtonHidden(_:)` is unavailable on the deployment target, replace with `.toolbar(removing: .title)` is NOT a substitute — instead drop that modifier and keep the custom back button alongside the system one; the discard confirm still works from the custom button.)

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Scanner/ScannerScreen.swift"
git commit -m "Add ScannerScreen (camera-first capture + save sheet)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: EmptyLibraryView

The welcoming guided empty state: hero title, 1-2-3 steps, and a prominent New Scan button.

**Files:**
- Create: `Codex Scanner/Views/Library/EmptyLibraryView.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Library/EmptyLibraryView.swift`:

```swift
//
//  EmptyLibraryView.swift
//  Codex Scanner
//

import SwiftUI

struct EmptyLibraryView: View {
    var onNewScan: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Scan your first book")
                    .font(.title2.weight(.semibold))
                Text("Prop your iPhone over a book and Codex Scanner captures each page automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                stepCard(number: 1, title: "Prop your iPhone", systemImage: "iphone")
                stepCard(number: 2, title: "Capture pages", systemImage: "camera.viewfinder")
                stepCard(number: 3, title: "Export PDF", systemImage: "arrow.up.doc")
            }

            Button(action: onNewScan) {
                Label("New Scan", systemImage: "plus")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
        .padding(Theme.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stepCard(number: Int, title: String, systemImage: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
        return VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(.tint)
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .frame(width: 120, height: 110)
        .padding(Theme.Spacing.md)
        .background(Color.appSurface, in: shape)
        .overlay(shape.stroke(Color.appBorder, lineWidth: 0.5))
    }
}

#Preview {
    EmptyLibraryView(onNewScan: {})
        .frame(width: 700, height: 520)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Library/EmptyLibraryView.swift"
git commit -m "Add EmptyLibraryView (welcoming empty state)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: BookCoverCard

One book on the shelf: cover image (first page) or placeholder, title, page count. Navigates via `Route.book`. Context menu: rename / export / delete (handled by parent via closures).

**Files:**
- Create: `Codex Scanner/Views/Library/BookCoverCard.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Library/BookCoverCard.swift`:

```swift
//
//  BookCoverCard.swift
//  Codex Scanner
//

import SwiftUI

struct BookCoverCard: View {
    let book: Book
    var onRename: () -> Void
    var onExport: () -> Void
    var onDelete: () -> Void

    var body: some View {
        NavigationLink(value: Route.book(book)) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                cover
                Text(book.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("\(book.pageCount) page\(book.pageCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onRename() } label: { Label("Rename…", systemImage: "pencil") }
            Button { onExport() } label: { Label("Export as PDF…", systemImage: "arrow.up.doc") }
                .disabled(book.pages.isEmpty)
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
        return ZStack {
            shape.fill(Color.appContentBackground)
            if let image = book.coverPage?.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 150)
        .clipShape(shape)
        .overlay(shape.stroke(Color.appBorder, lineWidth: 0.5))
    }
}

#Preview {
    NavigationStack {
        BookCoverCard(book: Book(title: "Sample Book"), onRename: {}, onExport: {}, onDelete: {})
            .frame(width: 170)
            .padding()
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Library/BookCoverCard.swift"
git commit -m "Add BookCoverCard

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: PageGridCell

One page thumbnail inside a book. Navigates via `Route.page`.

**Files:**
- Create: `Codex Scanner/Views/Library/PageGridCell.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Library/PageGridCell.swift`:

```swift
//
//  PageGridCell.swift
//  Codex Scanner
//

import SwiftUI

struct PageGridCell: View {
    let page: Page
    let pageNumber: Int

    var body: some View {
        NavigationLink(value: Route.page(page)) {
            VStack(spacing: Theme.Spacing.xs) {
                thumbnail
                Text("Page \(pageNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        return ZStack {
            shape.fill(Color.appContentBackground)
            if let image = page.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .frame(height: 160)
        .clipShape(shape)
        .overlay(shape.stroke(Color.appBorder, lineWidth: 0.5))
    }
}

#Preview {
    NavigationStack {
        PageGridCell(page: Page(imagePath: "x.jpg"), pageNumber: 1)
            .frame(width: 170)
            .padding()
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Library/PageGridCell.swift"
git commit -m "Add PageGridCell

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: PageEditorScreen

The page editor (3rd push level): rotate left/right and a filter-preset menu, all system controls.

**Files:**
- Create: `Codex Scanner/Views/Library/PageEditorScreen.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Library/PageEditorScreen.swift`:

```swift
//
//  PageEditorScreen.swift
//  Codex Scanner
//

import SwiftUI
import AppKit
import CoreImage

struct PageEditorScreen: View {
    let page: Page
    @State private var preset: ImageProcessor.FilterPreset = .original
    @State private var rotation: Double = 0
    @State private var displayImage: NSImage?

    private let imageProcessor = ImageProcessor()

    var body: some View {
        VStack(spacing: 0) {
            imageArea
            Divider()
            controls
        }
        .navigationTitle("Page \(page.order + 1)")
        .task { displayImage = page.image }
    }

    private var imageArea: some View {
        Group {
            if let image = displayImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(.degrees(rotation))
                        .padding(Theme.Spacing.xl)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView(
                    "No Image",
                    systemImage: "photo",
                    description: Text("Could not load this page's image")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button { rotation -= 90 } label: { Label("Rotate Left", systemImage: "rotate.left") }
            Button { rotation += 90 } label: { Label("Rotate Right", systemImage: "rotate.right") }
            Divider().frame(height: 20)
            Picker("Filter", selection: $preset) {
                ForEach(ImageProcessor.FilterPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            .onChange(of: preset) { _, newValue in applyPreset(newValue) }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(.bar)
    }

    private func applyPreset(_ preset: ImageProcessor.FilterPreset) {
        guard let original = page.image,
              let tiff = original.tiffRepresentation,
              let ciImage = CIImage(data: tiff) else { return }
        let processed = imageProcessor.applyPreset(preset, to: ciImage)
        displayImage = imageProcessor.nsImage(from: processed)
    }
}

#Preview {
    NavigationStack {
        PageEditorScreen(page: Page(imagePath: "x.jpg"))
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Library/PageEditorScreen.swift"
git commit -m "Add PageEditorScreen (rotate + filter presets)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: BookDetailView

The page grid for one book: a `LazyVGrid` of `PageGridCell`, toolbar Rename + Export PDF, a rename sheet, an `NSSavePanel` export, and a delete-page context menu.

**Files:**
- Create: `Codex Scanner/Views/Library/BookDetailView.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Library/BookDetailView.swift`:

```swift
//
//  BookDetailView.swift
//  Codex Scanner
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct BookDetailView: View {
    @Bindable var book: Book
    @State private var showRename = false
    @State private var newTitle = ""

    private let pdfGenerator = PDFGenerator()

    var body: some View {
        Group {
            if book.pages.isEmpty {
                ContentUnavailableView(
                    "No Pages Yet",
                    systemImage: "doc.text.image",
                    description: Text("Scan pages to add them to this book.")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Theme.Spacing.lg)],
                        spacing: Theme.Spacing.xl
                    ) {
                        ForEach(Array(book.sortedPages.enumerated()), id: \.element.id) { index, page in
                            PageGridCell(page: page, pageNumber: index + 1)
                                .contextMenu {
                                    Button(role: .destructive) { deletePage(page) } label: {
                                        Label("Delete Page", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(Theme.Spacing.xl)
                }
            }
        }
        .navigationTitle(book.title)
        .toolbar {
            ToolbarItem {
                Button { newTitle = book.title; showRename = true } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            ToolbarItem {
                Button { exportPDF() } label: { Label("Export PDF", systemImage: "arrow.up.doc") }
                    .disabled(book.pages.isEmpty)
            }
        }
        .sheet(isPresented: $showRename) { renameSheet }
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Rename Book").font(.headline)
            TextField("Title", text: $newTitle).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { showRename = false }
                Button("Save") {
                    book.title = newTitle
                    showRename = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newTitle.isEmpty)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 320)
    }

    private func deletePage(_ page: Page) {
        page.deleteImageFile()
        book.removePage(page)
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(book.title).pdf"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try pdfGenerator.export(book: book, to: url)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                NSSound.beep()
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Library/BookDetailView.swift"
git commit -m "Add BookDetailView (page grid + rename/export)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: LibraryHomeView

The navigation root: empty state when there are no books, else a cover-gallery `LazyVGrid`. Toolbar has the primary New Scan button; rename/export/delete are handled here.

**Files:**
- Create: `Codex Scanner/Views/Library/LibraryHomeView.swift`

- [ ] **Step 1: Write the view**

Create `Codex Scanner/Views/Library/LibraryHomeView.swift`:

```swift
//
//  LibraryHomeView.swift
//  Codex Scanner
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct LibraryHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    var onNewScan: () -> Void

    @State private var renameTarget: Book?
    @State private var renameText = ""

    private let pdfGenerator = PDFGenerator()

    var body: some View {
        Group {
            if books.isEmpty {
                EmptyLibraryView(onNewScan: onNewScan)
            } else {
                gallery
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNewScan) { Label("New Scan", systemImage: "plus") }
            }
        }
        .sheet(item: $renameTarget) { book in renameSheet(book) }
    }

    private var gallery: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Theme.Spacing.lg)],
                spacing: Theme.Spacing.xl
            ) {
                ForEach(books) { book in
                    BookCoverCard(
                        book: book,
                        onRename: { renameText = book.title; renameTarget = book },
                        onExport: { exportPDF(book) },
                        onDelete: { deleteBook(book) }
                    )
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }

    private func renameSheet(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Rename Book").font(.headline)
            TextField("Title", text: $renameText).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { renameTarget = nil }
                Button("Save") {
                    book.title = renameText
                    renameTarget = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(renameText.isEmpty)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 320)
    }

    private func deleteBook(_ book: Book) {
        for page in book.pages { page.deleteImageFile() }
        modelContext.delete(book)
    }

    private func exportPDF(_ book: Book) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(book.title).pdf"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try pdfGenerator.export(book: book, to: url)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                NSSound.beep()
            }
        }
    }
}

#Preview {
    NavigationStack {
        LibraryHomeView(onNewScan: {})
    }
    .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' build 2>&1 | tail -n 20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Codex Scanner/Views/Library/LibraryHomeView.swift"
git commit -m "Add LibraryHomeView (empty state + cover gallery)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Switch the shell to the new window

Flip the app entry from the old tab-based `ContentView` to the new `NavigationStack` shell, replace the View-menu `TabCommands` with a File ▸ New Scan (`ScanCommands`), and update the app scene. After this task the running app is the new experience. The three files change together so the build stays green.

**Files:**
- Modify (full rewrite): `Codex Scanner/ContentView.swift`
- Modify (full rewrite): `Codex Scanner/AppCommands.swift`
- Modify: `Codex Scanner/Codex_ScannerApp.swift`

- [ ] **Step 1: Rewrite ContentView**

Replace the entire contents of `Codex Scanner/ContentView.swift` with:

```swift
//
//  ContentView.swift
//  Codex Scanner
//
//  The single-window navigation shell.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            LibraryHomeView(onNewScan: pushScan)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .book(let book): BookDetailView(book: book)
                    case .page(let page): PageEditorScreen(page: page)
                    case .scan: ScannerScreen()
                    }
                }
        }
        .frame(minWidth: 900, minHeight: 650)
        .focusedSceneValue(\.navigationPath, $path)
    }

    private func pushScan() {
        if path.last != .scan { path.append(.scan) }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
```

- [ ] **Step 2: Rewrite AppCommands**

Replace the entire contents of `Codex Scanner/AppCommands.swift` with:

```swift
//
//  AppCommands.swift
//  Codex Scanner
//
//  Menu-bar commands for the single-window shell.
//

import SwiftUI

/// File ▸ New Scan (⌘N). Pushes the scanner onto the focused window's nav path.
struct ScanCommands: Commands {
    @FocusedValue(\.navigationPath) private var path

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Scan") {
                if path?.wrappedValue.last != .scan {
                    path?.wrappedValue.append(.scan)
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(path == nil)
        }
    }
}
```

- [ ] **Step 3: Update the app scene**

In `Codex Scanner/Codex_ScannerApp.swift`, change the `WindowGroup` modifiers. Replace:

```swift
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 650)
        .commands {
            TabCommands()
        }
```

with:

```swift
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 900, height: 650)
        .commands {
            ScanCommands()
        }
```

- [ ] **Step 4: Build and run the full test suite**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **` (the old `ScannerView`/`LibraryView`/etc. are now unreferenced but still compile.)

- [ ] **Step 5: Commit**

```bash
git add "Codex Scanner/ContentView.swift" "Codex Scanner/AppCommands.swift" "Codex Scanner/Codex_ScannerApp.swift"
git commit -m "Switch app shell to home-first NavigationStack (New Scan ⌘N)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Delete the old UI and smoke-test

Remove the now-unreferenced old views, the old ViewModel, the hand-rolled styles, the dead components, and the obsolete `ScanningState` model. Then verify a clean build, the full test suite, and a manual smoke test.

**Files (delete):** see command below.

- [ ] **Step 1: Delete old files**

```bash
cd "/Users/aaraalto/Developer/02 MacOS/Codex Scanner/Codex Scanner"
rm -f Views/ScannerView.swift
rm -f Views/LibraryView.swift
rm -f Views/EditorView.swift
rm -f Views/PreviewView.swift
rm -f ViewModels/ScannerViewModel.swift
rm -f Models/ScanningState.swift
rm -f Views/Components/NotionButtonStyles.swift
rm -f Views/Components/NotionControlStyles.swift
rm -f Views/Components/SolidToggleStyle.swift
rm -f Views/Components/CaptureSuccessOverlay.swift
rm -f Views/Components/DocumentBoundsOverlay.swift
rm -f Views/Components/ScannedPagesStrip.swift
rm -f Views/Components/PageThumbnail.swift
rm -f Views/Components/ScanThumbnail.swift
rm -f Views/Components/PreviewThumbnail.swift
rm -f Views/Components/CameraSelector.swift
rm -f Views/Components/CapturedPageRow.swift
rm -f Views/Components/ProcessingModeSelector.swift
```

- [ ] **Step 2: Verify no dangling references remain**

```bash
cd "/Users/aaraalto/Developer/02 MacOS/Codex Scanner/Codex Scanner"
grep -rIn -e "notion" -e "SolidToggle" -e "CaptureSuccessOverlay" -e "ScanningState" -e "ScanOrientation" -e "ScannerViewModel" -e "displayBounds" -e "stabilityProgress" . --include="*.swift"
```
Expected: no output (an empty result). If anything prints, it is a leftover reference — fix it before continuing.

- [ ] **Step 3: Build and run the full test suite**

Run: `xcodebuild -scheme "Codex Scanner" -destination 'platform=macOS' test 2>&1 | tail -n 30`
Expected: `** TEST SUCCEEDED **` with 0 warnings.

- [ ] **Step 4: Manual smoke test**

Launch the app from Xcode (⌘R) and verify:
- [ ] Launches into **Library** (not the camera).
- [ ] Empty library shows the welcoming hero; **New Scan** (button and ⌘N) opens the scanner.
- [ ] Scanner shows the camera feed; the document frame appears when a page is in view; auto-capture fires on a stable page; the shutter button captures manually.
- [ ] Captured pages appear in the strip; **Save to Book…** creates a new book (or appends), then returns to the Library with the new book on the shelf.
- [ ] `‹ Library` with unsaved captured pages prompts to discard.
- [ ] Tapping a book opens its page grid; tapping a page opens the editor (rotate + filters work).
- [ ] **Export PDF** (book toolbar and cover context menu) writes a valid PDF and reveals it in Finder.
- [ ] Rename and Delete work from the cover context menu.

- [ ] **Step 5: Commit**

```bash
cd "/Users/aaraalto/Developer/02 MacOS/Codex Scanner"
git add -A
git commit -m "Remove old tab-based UI, hand-rolled styles, and dead components

Completes the home-first single-window rebuild. Camera/processing
services and SwiftData models are unchanged; the view layer is now
pure-system macOS.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** Home-first window (Tasks 13/14) ✓ · welcoming empty state (8) ✓ · cover gallery (9/13) ✓ · push-in Library→Book→Page (10/11/12/14) ✓ · clean camera-first scanner pushed in with `‹ back` + discard confirm (3–7) ✓ · save-to-book → pop to home (7) ✓ · pure-system styling + delete hand-rolled styles (all view tasks + 15) ✓ · ⌘N New Scan (14) ✓ · services/models kept (untouched) ✓ · `ScannerPhase` state machine (3) ✓ · resolved v1 decisions: drag-reorder deferred (not built), editor minimal (11), cover = first page (2/9), New Scan = fresh session with save-time book choice (7) ✓.

**Placeholder scan:** No TBD/TODO; every code step is complete and compilable.

**Type consistency:** New names used consistently — `ScannerModel`, `ScannerPhase`, `ScannerScreen`, `DocumentFrameOverlay`, `CaptureControlsBar`, `CapturedPagesStrip`, `LibraryHomeView`, `EmptyLibraryView`, `BookCoverCard`, `PageGridCell`, `PageEditorScreen`, `BookDetailView`, `Route`, `ScanCommands`. Service/model APIs match the real signatures (`saveToBook(_:modelContext:)`, `imageProcessor.process(image:bounds:preset:mode:enhance:)`, `pdfGenerator.export(book:to:)`, `book.addPage`, `book.removePage`, `page.deleteImageFile`).

**Known platform risk:** `navigationBarBackButtonHidden(_:)` on macOS — handled with a fallback note in Task 7, Step 2.
