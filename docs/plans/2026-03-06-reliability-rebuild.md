# Codex Scanner Reliability Rebuild - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Strip down Codex Scanner to a reliable core: scan pages with auto-detection, save to books, export PDF. Rewrite ViewModel and Views with native macOS controls; keep services and data models.

**Architecture:** Enum-driven state machine ViewModel replaces the current @Published-boolean approach. All views rebuilt with system controls only -- no custom styles, no Metal shaders, no animations beyond what SwiftUI provides natively.

**Tech Stack:** SwiftUI, SwiftData, AVFoundation, Vision, CoreImage, PDFKit (all existing -- no new dependencies)

---

### Task 1: Delete Unused Custom UI Files

Remove files that won't be needed in the rebuild. This must happen first to avoid compile errors from dangling references during the rewrite.

**Files:**
- Delete: `Codex Scanner/Views/Components/NotionButtonStyles.swift`
- Delete: `Codex Scanner/Views/Components/NotionControlStyles.swift`
- Delete: `Codex Scanner/Views/Components/SolidToggleStyle.swift`
- Delete: `Codex Scanner/Views/Components/CaptureSuccessOverlay.swift`
- Delete: `Codex Scanner/Shaders/ParticleDissolve.metal`
- Delete: `Codex Scanner/Views/Components/CameraSelector.swift`
- Delete: `Codex Scanner/Views/Components/CapturedPageRow.swift`
- Delete: `Codex Scanner/Views/Components/ProcessingModeSelector.swift`
- Delete: `Codex Scanner/Views/Components/PreviewThumbnail.swift`
- Delete: `Codex Scanner/Views/Components/ScanThumbnail.swift`
- Delete: `Codex Scanner/Views/Components/PageThumbnail.swift`

**Step 1: Delete files**

```bash
cd "Codex Scanner"
rm -f Views/Components/NotionButtonStyles.swift
rm -f Views/Components/NotionControlStyles.swift
rm -f Views/Components/SolidToggleStyle.swift
rm -f Views/Components/CaptureSuccessOverlay.swift
rm -f Shaders/ParticleDissolve.metal
rm -f Views/Components/CameraSelector.swift
rm -f Views/Components/CapturedPageRow.swift
rm -f Views/Components/ProcessingModeSelector.swift
rm -f Views/Components/PreviewThumbnail.swift
rm -f Views/Components/ScanThumbnail.swift
rm -f Views/Components/PageThumbnail.swift
```

**Step 2: Remove the Shaders group from Xcode project if it exists**

Check if the Shaders folder is now empty and remove it:
```bash
rmdir Shaders 2>/dev/null || true
```

**Step 3: Commit**

```bash
git add -A
git commit -m "Remove custom UI styles, Metal shader, and component files

Preparing for reliability rebuild with native macOS controls."
```

---

### Task 2: Rewrite ScannerViewModel with State Machine

Replace the 683-line ViewModel with a clean state machine. This is the critical reliability fix -- the current approach uses ~20 @Published booleans that can desync.

**Files:**
- Rewrite: `Codex Scanner/ViewModels/ScannerViewModel.swift`

**Step 1: Write the new ScannerViewModel**

The new ViewModel uses an explicit `ScannerPhase` enum. Key differences from old code:
- Single `@Published var phase: ScannerPhase` replaces `scanningState`, `isProcessing`, `showCaptureSuccess`, `isOnCooldown`, `isBoundsLocked`, etc.
- No bounds smoothing, no orientation filtering, no cooldown timer
- No `ScanOrientation` enum -- removed
- Keeps Combine bindings to CameraManager (these are stable)
- Keeps `capturedPages` array management
- Keeps `saveToBook()` and export methods

```swift
//
//  ScannerViewModel.swift
//  Codex Scanner
//

import SwiftUI
import SwiftData
import Combine
import CoreImage
import AppKit

/// The scanner's current operational phase
enum ScannerPhase: Equatable {
    case idle                                    // Camera on, not scanning
    case scanning                                // Actively looking for documents
    case capturing                               // Photo is being taken
    case processing                              // Processing the captured photo

    static func == (lhs: ScannerPhase, rhs: ScannerPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning),
             (.capturing, .capturing), (.processing, .processing):
            return true
        default:
            return false
        }
    }
}

@MainActor
final class ScannerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var phase: ScannerPhase = .idle
    @Published var isAutoScanEnabled = true
    @Published var detectedBounds: ImageProcessor.DocumentBounds?
    @Published var capturedPages: [CapturedPage] = []
    @Published var selectedProcessingMode: ImageProcessor.ProcessingMode = .mixed
    @Published var exportQuality: ImageProcessor.ExportQuality = .high
    @Published var errorMessage: String?
    @Published var isCameraReady = false

    // MARK: - Services

    let cameraManager = CameraManager()
    let imageProcessor = ImageProcessor()

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var stableFrameCount = 0
    private let stabilityThreshold = 25
    private let boundsMovementThreshold: CGFloat = 0.015

    // MARK: - Init

    init() {
        setupBindings()
    }

    // MARK: - Camera Lifecycle

    func initializeCamera() async {
        await cameraManager.startSession()
        isCameraReady = true
    }

    func startScanning() async {
        if !isCameraReady {
            await cameraManager.startSession()
            isCameraReady = true
        }
        phase = .scanning
    }

    func stopScanning() {
        cameraManager.stopSession()
        phase = .idle
        isCameraReady = false
        resetStability()
    }

    func pauseScanning() {
        phase = .idle
        resetStability()
    }

    func toggleScanning() {
        if phase == .scanning {
            pauseScanning()
        } else {
            Task { await startScanning() }
        }
    }

    // MARK: - Capture

    func capturePhoto() {
        guard phase == .scanning else { return }
        phase = .capturing
        cameraManager.capturePhoto()
    }

    // MARK: - Page Management

    func removePage(_ page: CapturedPage) {
        capturedPages.removeAll { $0.id == page.id }
    }

    func clearAllPages() {
        capturedPages.removeAll()
    }

    func movePage(from source: IndexSet, to destination: Int) {
        capturedPages.move(fromOffsets: source, toOffset: destination)
    }

    func updateProcessingMode(_ mode: ImageProcessor.ProcessingMode, for page: CapturedPage) {
        guard let index = capturedPages.firstIndex(where: { $0.id == page.id }) else { return }
        var updated = capturedPages[index]
        updated.processingMode = mode
        updated.processedImage = imageProcessor.process(
            image: updated.originalImage,
            bounds: updated.bounds,
            preset: updated.preset,
            mode: mode,
            enhance: true
        )
        updated.thumbnail = imageProcessor.createHighResThumbnail(
            from: updated.processedImage,
            size: NSSize(width: 150, height: 200)
        )
        capturedPages[index] = updated
    }

    // MARK: - Save to Book

    func saveToBook(_ book: Book, modelContext: ModelContext) async throws {
        let previousPhase = phase
        phase = .processing
        defer { phase = previousPhase }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bookFolder = documentsURL.appendingPathComponent(book.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookFolder, withIntermediateDirectories: true)

        let fileExtension = exportQuality == .maximum ? "png" : "jpg"

        for (index, capturedPage) in capturedPages.enumerated() {
            let filename = "\(UUID().uuidString).\(fileExtension)"
            let fileURL = bookFolder.appendingPathComponent(filename)

            let correctedImage = correctOrientation(capturedPage.processedImage)
            try imageProcessor.save(image: correctedImage, to: fileURL, quality: exportQuality)

            let relativePath = "\(book.id.uuidString)/\(filename)"
            let page = Page(imagePath: relativePath, order: book.pageCount + index)
            book.addPage(page)
        }

        try modelContext.save()
        capturedPages.removeAll()
    }

    func getExportImages() -> [NSImage] {
        capturedPages.compactMap { imageProcessor.nsImage(from: $0.processedImage) }
    }

    // MARK: - Private

    private func correctOrientation(_ image: CIImage) -> CIImage {
        guard let orientationValue = image.properties[kCGImagePropertyOrientation as String] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: orientationValue) else {
            return image
        }
        return image.oriented(orientation)
    }

    private func resetStability() {
        stableFrameCount = 0
        detectedBounds = nil
    }

    private func setupBindings() {
        // Camera errors
        cameraManager.$error
            .compactMap { $0?.localizedDescription }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.errorMessage = message
            }
            .store(in: &cancellables)

        // Frame processing for document detection
        cameraManager.framePublisher
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.global(qos: .userInteractive), latest: true)
            .sink { [weak self] pixelBuffer in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    guard let self = self, self.phase == .scanning else { return }
                    let processor = self.imageProcessor
                    let bounds = await Task.detached {
                        processor.detectDocument(in: pixelBuffer)
                    }.value
                    self.handleDetectedBounds(bounds)
                }
            }
            .store(in: &cancellables)

        // Photo capture handling
        cameraManager.photoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ciImage in
                Task { @MainActor in
                    await self?.processPhoto(ciImage)
                }
            }
            .store(in: &cancellables)
    }

    private func handleDetectedBounds(_ bounds: ImageProcessor.DocumentBounds?) {
        guard phase == .scanning else { return }

        detectedBounds = bounds

        guard let newBounds = bounds, let oldBounds = detectedBounds else {
            stableFrameCount = 0
            return
        }

        let movement = maxCornerMovement(from: oldBounds, to: newBounds)

        if movement < boundsMovementThreshold {
            stableFrameCount += 1
            if isAutoScanEnabled && stableFrameCount >= stabilityThreshold {
                stableFrameCount = 0
                capturePhoto()
            }
        } else {
            stableFrameCount = max(0, stableFrameCount - 2)
        }
    }

    private func maxCornerMovement(from old: ImageProcessor.DocumentBounds, to new: ImageProcessor.DocumentBounds) -> CGFloat {
        let movements = [
            distance(old.topLeft, new.topLeft),
            distance(old.topRight, new.topRight),
            distance(old.bottomLeft, new.bottomLeft),
            distance(old.bottomRight, new.bottomRight)
        ]
        return movements.max() ?? 0
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2))
    }

    private func processPhoto(_ ciImage: CIImage) async {
        phase = .processing
        defer {
            phase = .scanning
            stableFrameCount = 0
        }

        let orientedImage = correctOrientation(ciImage)

        let bounds: ImageProcessor.DocumentBounds?
        if let detected = detectedBounds {
            bounds = detected
        } else {
            bounds = await imageProcessor.detectDocument(in: orientedImage)
        }

        let processed = imageProcessor.process(
            image: orientedImage,
            bounds: bounds,
            preset: .original,
            mode: selectedProcessingMode,
            enhance: true
        )

        let thumbnail = imageProcessor.createHighResThumbnail(
            from: processed,
            size: NSSize(width: 150, height: 200)
        )

        let page = CapturedPage(
            originalImage: orientedImage,
            processedImage: processed,
            bounds: bounds,
            preset: .original,
            processingMode: selectedProcessingMode,
            thumbnail: thumbnail
        )

        capturedPages.append(page)

        // Play capture sound
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Pop") {
            sound.play()
        }
    }
}
```

**Step 2: Verify it compiles in isolation**

The ViewModel only depends on Models and Services which are untouched. It should compile even though views are temporarily broken.

**Step 3: Commit**

```bash
git add Codex\ Scanner/ViewModels/ScannerViewModel.swift
git commit -m "Rewrite ScannerViewModel with enum-driven state machine

Replaces ~20 @Published booleans with single ScannerPhase enum.
Removes bounds smoothing, orientation filtering, cooldown timer,
and bounds locking. Keeps core capture pipeline unchanged."
```

---

### Task 3: Simplify CameraPreview (Remove Zoom)

Strip the CameraPreview down to just show the camera feed. Remove scroll-wheel zoom handling.

**Files:**
- Rewrite: `Codex Scanner/Views/Components/CameraPreview.swift`

**Step 1: Write simplified CameraPreview**

```swift
//
//  CameraPreview.swift
//  Codex Scanner
//

import SwiftUI
import AVFoundation

/// NSViewRepresentable wrapper for AVCaptureVideoPreviewLayer
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.session = session
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.refreshSession(session)
    }
}

final class CameraPreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var sessionObserver: NSKeyValueObservation?

    var session: AVCaptureSession? {
        didSet { setupPreviewLayer() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    deinit {
        sessionObserver?.invalidate()
    }

    func refreshSession(_ session: AVCaptureSession) {
        if self.session !== session {
            self.session = session
        } else if previewLayer == nil {
            setupPreviewLayer()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer?.frame = bounds
            CATransaction.commit()
        }
    }

    private func setupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()
        sessionObserver?.invalidate()

        guard let session = session else { return }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer?.addSublayer(layer)
        self.previewLayer = layer

        // Reconnect layer when session starts running
        sessionObserver = session.observe(\.isRunning, options: [.new]) { [weak self] session, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if session.isRunning, self.previewLayer?.session !== session {
                    self.setupPreviewLayer()
                }
            }
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && previewLayer == nil && session != nil {
            setupPreviewLayer()
        }
    }
}
```

**Step 2: Commit**

```bash
git add Codex\ Scanner/Views/Components/CameraPreview.swift
git commit -m "Simplify CameraPreview: remove zoom, streamline session handling"
```

---

### Task 4: Rewrite DocumentBoundsOverlay

Replace the current overlay with a simple shape that draws four corner markers connected by lines.

**Files:**
- Rewrite: `Codex Scanner/Views/Components/DocumentBoundsOverlay.swift`

**Step 1: Write the new overlay**

```swift
//
//  DocumentBoundsOverlay.swift
//  Codex Scanner
//

import SwiftUI

/// Draws detected document bounds as corner markers over the camera preview
struct DocumentBoundsOverlay: View {
    let bounds: ImageProcessor.DocumentBounds
    let viewSize: CGSize

    var body: some View {
        Canvas { context, size in
            let tl = denormalize(bounds.topLeft, in: size)
            let tr = denormalize(bounds.topRight, in: size)
            let bl = denormalize(bounds.bottomLeft, in: size)
            let br = denormalize(bounds.bottomRight, in: size)

            // Draw border path
            var path = Path()
            path.move(to: tl)
            path.addLine(to: tr)
            path.addLine(to: br)
            path.addLine(to: bl)
            path.closeSubpath()

            context.stroke(path, with: .color(.blue), lineWidth: 2)

            // Draw corner dots
            let cornerSize: CGFloat = 8
            for point in [tl, tr, bl, br] {
                let rect = CGRect(
                    x: point.x - cornerSize / 2,
                    y: point.y - cornerSize / 2,
                    width: cornerSize,
                    height: cornerSize
                )
                context.fill(Path(ellipseIn: rect), with: .color(.blue))
            }
        }
        .allowsHitTesting(false)
    }

    /// Convert normalized Vision coordinates (origin bottom-left) to view coordinates (origin top-left)
    private func denormalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )
    }
}
```

**Step 2: Commit**

```bash
git add Codex\ Scanner/Views/Components/DocumentBoundsOverlay.swift
git commit -m "Rewrite DocumentBoundsOverlay with simple Canvas-based corners"
```

---

### Task 5: Rewrite ScannedPagesStrip

Simple horizontal scroll of thumbnails showing captured pages.

**Files:**
- Rewrite: `Codex Scanner/Views/Components/ScannedPagesStrip.swift`

**Step 1: Write new strip**

```swift
//
//  ScannedPagesStrip.swift
//  Codex Scanner
//

import SwiftUI

/// Horizontal strip of captured page thumbnails
struct ScannedPagesStrip: View {
    let pages: [CapturedPage]
    let onDelete: (CapturedPage) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    VStack(spacing: 4) {
                        if let thumbnail = page.thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 60, height: 80)
                        }

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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 110)
        .background(.bar)
    }
}
```

**Step 2: Commit**

```bash
git add Codex\ Scanner/Views/Components/ScannedPagesStrip.swift
git commit -m "Rewrite ScannedPagesStrip with native thumbnails"
```

---

### Task 6: Rewrite ScannerView

This is the biggest task. Replace the 1200-line view with a clean native macOS layout. The view has three sections: camera preview with overlay, controls bar, and thumbnail strip.

**Files:**
- Rewrite: `Codex Scanner/Views/ScannerView.swift`

**Step 1: Write the new ScannerView**

```swift
//
//  ScannerView.swift
//  Codex Scanner
//

import SwiftUI
import SwiftData

/// Main scanning view with camera preview and native controls
struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ScannerViewModel()
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    @State private var showingSaveSheet = false
    @State private var newBookTitle = "Untitled Book"
    @State private var selectedBookForSave: Book?
    @State private var isSaving = false

    var onNavigateToLibrary: (() -> Void)?
    var onBookSaved: ((UUID) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Camera preview with bounds overlay
            cameraSection

            Divider()

            // Controls bar
            controlsBar

            // Captured pages strip (only shown when pages exist)
            if !viewModel.capturedPages.isEmpty {
                Divider()
                ScannedPagesStrip(
                    pages: viewModel.capturedPages,
                    onDelete: { viewModel.removePage($0) }
                )
            }
        }
        .task {
            await viewModel.initializeCamera()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingSaveSheet) {
            saveSheet
        }
    }

    // MARK: - Camera Section

    private var cameraSection: some View {
        ZStack {
            CameraPreview(session: viewModel.cameraManager.session)

            if let bounds = viewModel.detectedBounds, viewModel.phase == .scanning {
                GeometryReader { geo in
                    DocumentBoundsOverlay(bounds: bounds, viewSize: geo.size)
                }
            }

            // Status indicator
            if viewModel.phase == .processing {
                ProgressView("Processing...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack(spacing: 16) {
            // Play/Pause
            Button {
                viewModel.toggleScanning()
            } label: {
                Label(
                    viewModel.phase == .scanning ? "Pause" : "Scan",
                    systemImage: viewModel.phase == .scanning ? "pause.fill" : "play.fill"
                )
            }

            // Manual capture
            Button {
                viewModel.capturePhoto()
            } label: {
                Label("Capture", systemImage: "camera.fill")
            }
            .disabled(viewModel.phase != .scanning)

            Divider().frame(height: 20)

            // Auto-capture toggle
            Toggle("Auto", isOn: $viewModel.isAutoScanEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            // Processing mode
            Picker("Mode", selection: $viewModel.selectedProcessingMode) {
                ForEach(ImageProcessor.ProcessingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            // Camera device picker
            if viewModel.cameraManager.availableDevices.count > 1 {
                Picker("Camera", selection: Binding(
                    get: { viewModel.cameraManager.currentDevice },
                    set: { device in
                        if let device = device {
                            Task { await viewModel.cameraManager.switchDevice(to: device) }
                        }
                    }
                )) {
                    ForEach(viewModel.cameraManager.availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(Optional(device))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }

            Spacer()

            // Page count & save
            if !viewModel.capturedPages.isEmpty {
                Text("\(viewModel.capturedPages.count) pages")
                    .foregroundStyle(.secondary)
                    .font(.callout)

                Button("Save to Book...") {
                    showingSaveSheet = true
                }
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Save Sheet

    private var saveSheet: some View {
        VStack(spacing: 16) {
            Text("Save \(viewModel.capturedPages.count) Pages")
                .font(.headline)

            // New book option
            HStack {
                TextField("New book title", text: $newBookTitle)
                    .textFieldStyle(.roundedBorder)

                Button("Create & Save") {
                    let book = Book(title: newBookTitle)
                    modelContext.insert(book)
                    saveToBook(book)
                }
                .disabled(newBookTitle.isEmpty || isSaving)
            }

            if !books.isEmpty {
                Divider()

                Text("Or add to existing book:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                List(books) { book in
                    Button {
                        saveToBook(book)
                    } label: {
                        HStack {
                            Text(book.title)
                            Spacer()
                            Text("\(book.pageCount) pages")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .disabled(isSaving)
                }
                .frame(height: min(CGFloat(books.count) * 30, 200))
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    showingSaveSheet = false
                }
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func saveToBook(_ book: Book) {
        isSaving = true
        Task {
            do {
                try await viewModel.saveToBook(book, modelContext: modelContext)
                onBookSaved?(book.id)
                showingSaveSheet = false
                newBookTitle = "Untitled Book"
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
```

**Step 2: Commit**

```bash
git add Codex\ Scanner/Views/ScannerView.swift
git commit -m "Rewrite ScannerView with native macOS controls

Replaces 1200-line view with ~200 lines. System buttons, toggles,
pickers. No custom styles, no animations, no Metal shaders."
```

---

### Task 7: Rewrite ContentView

Simplify to a basic TabView with no custom animations.

**Files:**
- Rewrite: `Codex Scanner/ContentView.swift`

**Step 1: Write new ContentView**

```swift
//
//  ContentView.swift
//  Codex Scanner
//

import SwiftUI
import SwiftData

/// Main content view with tab navigation
struct ContentView: View {
    @State private var selectedTab: Tab = .scanner
    @State private var newlySavedBookId: UUID?

    enum Tab: Hashable {
        case scanner
        case library
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScannerView(
                onNavigateToLibrary: { selectedTab = .library },
                onBookSaved: { bookId in
                    newlySavedBookId = bookId
                    selectedTab = .library
                }
            )
            .tabItem {
                Label("Scanner", systemImage: "camera.viewfinder")
            }
            .tag(Tab.scanner)

            LibraryView(newlySavedBookId: $newlySavedBookId)
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(Tab.library)
        }
        .frame(minWidth: 900, minHeight: 650)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
```

**Step 2: Commit**

```bash
git add Codex\ Scanner/ContentView.swift
git commit -m "Simplify ContentView to native TabView"
```

---

### Task 8: Rewrite LibraryView

Remove custom animations (entrance animations, ring bursts, New badges with timers) and Notion button styles. Keep NavigationSplitView structure.

**Files:**
- Rewrite: `Codex Scanner/Views/LibraryView.swift`

**Step 1: Write new LibraryView**

```swift
//
//  LibraryView.swift
//  Codex Scanner
//

import SwiftUI
import SwiftData
import AppKit

/// Book library with three-column NavigationSplitView
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @State private var selectedBook: Book?
    @State private var selectedPage: Page?
    @State private var showingRenameSheet = false
    @State private var newTitle = ""
    @Binding var newlySavedBookId: UUID?

    private let pdfGenerator = PDFGenerator()

    init(newlySavedBookId: Binding<UUID?> = .constant(nil)) {
        self._newlySavedBookId = newlySavedBookId
    }

    var body: some View {
        NavigationSplitView {
            booksList
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } content: {
            if let book = selectedBook {
                pagesGrid(for: book)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 400)
            } else {
                ContentUnavailableView(
                    "Select a Book",
                    systemImage: "book.closed",
                    description: Text("Choose a book from the sidebar to view its pages")
                )
            }
        } detail: {
            if let page = selectedPage {
                EditorView(page: page)
            } else {
                ContentUnavailableView(
                    "Select a Page",
                    systemImage: "doc.text.image",
                    description: Text("Choose a page to view and edit")
                )
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            renameSheet
        }
        .onChange(of: newlySavedBookId) { _, newId in
            if let bookId = newId,
               let book = books.first(where: { $0.id == bookId }) {
                selectedBook = book
                newlySavedBookId = nil
            }
        }
    }

    // MARK: - Books List

    private var booksList: some View {
        List(selection: $selectedBook) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .lineLimit(1)
                        Text("\(book.pageCount) \(book.pageCount == 1 ? "page" : "pages")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .contextMenu {
                    Button {
                        selectedBook = book
                        newTitle = book.title
                        showingRenameSheet = true
                    } label: {
                        Label("Rename...", systemImage: "pencil")
                    }

                    Button {
                        exportPDF(book: book)
                    } label: {
                        Label("Export as PDF...", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteBook(book)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteBooks)
        }
        .listStyle(.sidebar)
    }

    // MARK: - Pages Grid

    private func pagesGrid(for book: Book) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.title2.weight(.semibold))
                    Text("\(book.pageCount) \(book.pageCount == 1 ? "page" : "pages")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        newTitle = book.title
                        showingRenameSheet = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        exportPDF(book: book)
                    } label: {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                    .disabled(book.pages.isEmpty)
                }
            }
            .padding()

            Divider()

            if book.pages.isEmpty {
                ContentUnavailableView(
                    "No Pages Yet",
                    systemImage: "doc.text.image",
                    description: Text("Start scanning to add pages to this book")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 180))],
                        spacing: 20
                    ) {
                        ForEach(book.sortedPages) { page in
                            pageThumbnail(page)
                                .onTapGesture { selectedPage = page }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deletePage(page, from: book)
                                    } label: {
                                        Label("Delete Page", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: - Page Thumbnail (inline)

    private func pageThumbnail(_ page: Page) -> some View {
        VStack(spacing: 6) {
            if let image = page.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(selectedPage?.id == page.id ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    )
            }

            Text("Page \(page.order + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        Form {
            TextField("Title", text: $newTitle)
        }
        .formStyle(.grouped)
        .frame(width: 300, height: 80)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { showingRenameSheet = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    selectedBook?.title = newTitle
                    showingRenameSheet = false
                }
                .disabled(newTitle.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets { deleteBook(books[index]) }
    }

    private func deleteBook(_ book: Book) {
        for page in book.pages { page.deleteImageFile() }
        if selectedBook?.id == book.id { selectedBook = nil }
        modelContext.delete(book)
    }

    private func deletePage(_ page: Page, from book: Book) {
        page.deleteImageFile()
        book.removePage(page)
        if selectedPage?.id == page.id { selectedPage = nil }
    }

    private func exportPDF(book: Book) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(book.title).pdf"
        panel.canCreateDirectories = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try pdfGenerator.export(book: book, to: url)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } catch {
                    print("Export error: \(error)")
                }
            }
        }
    }
}

#Preview {
    LibraryView(newlySavedBookId: .constant(nil))
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
```

**Step 2: Commit**

```bash
git add Codex\ Scanner/Views/LibraryView.swift
git commit -m "Rewrite LibraryView with native styling, no custom animations

Removes entrance animations, ring bursts, Notion button styles.
Inlines page thumbnail (removes PageThumbnail dependency)."
```

---

### Task 9: Rewrite EditorView

Remove Notion styles and custom controls. Use system picker for filter presets and standard buttons for rotation.

**Files:**
- Rewrite: `Codex Scanner/Views/EditorView.swift`

**Step 1: Write new EditorView**

```swift
//
//  EditorView.swift
//  Codex Scanner
//

import SwiftUI
import AppKit

/// Page editor with rotation and filter presets
struct EditorView: View {
    let page: Page
    @State private var currentPreset: ImageProcessor.FilterPreset = .original
    @State private var rotation: Double = 0
    @State private var displayImage: NSImage?

    private let imageProcessor = ImageProcessor()

    var body: some View {
        VStack(spacing: 0) {
            // Image display
            Group {
                if let image = displayImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(.degrees(rotation))
                            .padding(32)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ContentUnavailableView(
                        "No Image",
                        systemImage: "photo",
                        description: Text("Could not load image")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // Controls
            HStack(spacing: 16) {
                Button {
                    rotation -= 90
                } label: {
                    Label("Rotate Left", systemImage: "rotate.left")
                }

                Button {
                    rotation += 90
                } label: {
                    Label("Rotate Right", systemImage: "rotate.right")
                }

                Divider().frame(height: 20)

                Picker("Filter", selection: $currentPreset) {
                    ForEach(ImageProcessor.FilterPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
                .onChange(of: currentPreset) { _, newValue in
                    applyPreset(newValue)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .task { loadImage() }
    }

    private func loadImage() {
        displayImage = page.image
    }

    private func applyPreset(_ preset: ImageProcessor.FilterPreset) {
        guard let originalImage = page.image,
              let tiffData = originalImage.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return }
        let processed = imageProcessor.applyPreset(preset, to: ciImage)
        displayImage = imageProcessor.nsImage(from: processed)
    }
}

#Preview {
    EditorView(page: Page(imagePath: "test.jpg"))
}
```

**Step 2: Commit**

```bash
git add Codex\ Scanner/Views/EditorView.swift
git commit -m "Rewrite EditorView with system controls"
```

---

### Task 10: Rewrite PreviewView

Simplify the standalone preview. This is a fallback view -- most preview happens inline in ScannerView now. Keep it simple.

**Files:**
- Rewrite: `Codex Scanner/Views/PreviewView.swift`

**Step 1: Write simplified PreviewView**

```swift
//
//  PreviewView.swift
//  Codex Scanner
//

import SwiftUI

/// Standalone page preview (fallback for detailed page review)
struct PreviewView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @Binding var isPresented: Bool
    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preview - \(viewModel.capturedPages.count) pages")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Page view
            if !viewModel.capturedPages.isEmpty,
               selectedIndex < viewModel.capturedPages.count {
                let page = viewModel.capturedPages[selectedIndex]
                ScrollView([.horizontal, .vertical]) {
                    if let image = page.displayImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(20)
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("No Pages", systemImage: "doc.text.image")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // Footer navigation
            HStack {
                Button {
                    selectedIndex = max(0, selectedIndex - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(selectedIndex == 0)

                Text("Page \(selectedIndex + 1) of \(viewModel.capturedPages.count)")
                    .frame(minWidth: 120)

                Button {
                    selectedIndex = min(viewModel.capturedPages.count - 1, selectedIndex + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(selectedIndex >= viewModel.capturedPages.count - 1)

                Spacer()

                Button("Continue Scanning") {
                    isPresented = false
                }
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

#Preview {
    PreviewView(
        viewModel: ScannerViewModel(),
        isPresented: .constant(true)
    )
}
```

**Step 2: Commit**

```bash
git add Codex\ Scanner/Views/PreviewView.swift
git commit -m "Simplify PreviewView with native controls"
```

---

### Task 11: Remove Unused ScanningState Model

The old `ScanningState` enum (Stopped/Scanning/Paused) is replaced by `ScannerPhase` in the ViewModel. Check if anything still references it.

**Files:**
- Potentially delete: `Codex Scanner/Models/ScanningState.swift`

**Step 1: Search for usages**

```bash
grep -r "ScanningState" "Codex Scanner/" --include="*.swift" -l
```

If only `ScanningState.swift` itself references it, delete it. If other files reference it, check if those references were already removed by earlier tasks.

**Step 2: Delete if unused**

```bash
rm "Codex Scanner/Models/ScanningState.swift"
```

**Step 3: Commit**

```bash
git add -A
git commit -m "Remove unused ScanningState model (replaced by ScannerPhase)"
```

---

### Task 12: Verify Build and Test

Build the project and fix any compile errors from dangling references.

**Step 1: Build**

```bash
cd "/Users/aaraalto/Developer/Codex Scanner"
xcodebuild -scheme "Codex Scanner" -destination "platform=macOS" build 2>&1 | tail -50
```

**Step 2: Fix any compile errors**

Common issues to check:
- References to deleted styles (`.notionBorderless`, `.notionPrimary`, `.notionSecondary`, `.notionSegmentedPicker()`)
- References to `Color.notionSurface`, `Color.notionBorder`
- References to `Color(hex:)` -- keep `Color+Hex.swift` as it may still be needed
- References to deleted components (`PageThumbnail`, `ScanThumbnail`, etc.)
- References to removed ViewModel properties (`smoothedBounds`, `isBoundsLocked`, `zoomFactor`, `scanOrientation`, etc.)

**Step 3: Commit fixes**

```bash
git add -A
git commit -m "Fix compile errors from rebuild"
```

---

### Task 13: Smoke Test

Launch the app and verify core workflows work. This is a manual testing task.

**Checklist:**
- [ ] App launches without crash
- [ ] Camera feed appears in scanner tab
- [ ] Document detection overlay shows when document is in frame
- [ ] Manual capture button works
- [ ] Auto-capture triggers after stable detection
- [ ] Captured pages appear in thumbnail strip
- [ ] Save to new book works
- [ ] Library tab shows saved book
- [ ] Pages display in library grid
- [ ] Export PDF creates valid PDF file
- [ ] Switching between Scanner/Library tabs works

**Step 1: Run the app**

```bash
cd "/Users/aaraalto/Developer/Codex Scanner"
xcodebuild -scheme "Codex Scanner" -destination "platform=macOS" build
open "build/Build/Products/Debug/Codex Scanner.app" 2>/dev/null || echo "Open from Xcode instead"
```

**Step 2: Fix any runtime issues found**

**Step 3: Final commit**

```bash
git add -A
git commit -m "Complete reliability rebuild: native macOS controls, state machine ViewModel

Stripped down from 1200+ line views and 20+ @Published booleans
to clean enum-driven state management with system controls."
```
