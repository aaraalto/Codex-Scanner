//
//  ScannerView.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import AppKit

/// Scanner mode - either capturing or reviewing
enum ScannerMode: String, CaseIterable {
    case scanning
    case preview
}

/// Main scanning view with camera preview and controls
/// Features sleek macOS Tahoe design with integrated preview mode
struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showingBookPicker = false
    @State private var showingTitleEditor = false
    @State private var newBookTitle = ""
    @State private var currentMode: ScannerMode = .scanning
    @State private var bookTitle: String = "Untitled Book"
    @State private var previewPageIndex: Int = 0
    @State private var previewZoom: Double = 1.0
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    
    // Save confirmation state
    @State private var showingSaveConfirmation = false
    @State private var savedBookCover: NSImage?
    @State private var savedBookTitle: String = ""
    @State private var savedBookPageCount: Int = 0
    @State private var savedBookId: UUID?
    
    // Callback to navigate to library with newly saved book ID
    var onNavigateToLibrary: (() -> Void)?
    var onBookSaved: ((UUID) -> Void)?
    var onBookArrived: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 0) {
                // Refined toolbar
                toolbarView
                
                // Main content - swaps between camera and preview
                mainContentView
                
                // Bottom thumbnail strip
                ScannedPagesStrip(
                    pages: viewModel.capturedPages,
                    coverImage: nil,
                    onDeletePage: { page in viewModel.removePage(page) },
                    onTapPage: { page in
                        if let index = viewModel.capturedPages.firstIndex(where: { $0.id == page.id }) {
                            previewPageIndex = index
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                currentMode = .preview
                            }
                        }
                    }
                )
            }
        }
        .task {
            await viewModel.initializeCamera()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingBookPicker) {
            bookPickerSheet
        }
        .sheet(isPresented: $showingTitleEditor) {
            titleEditorSheet
        }
        .overlay {
            if showingSaveConfirmation {
                BookSaveConfirmationOverlay(
                    coverImage: savedBookCover,
                    bookTitle: savedBookTitle,
                    pageCount: savedBookPageCount,
                    onBookArrived: {
                        onBookArrived?()
                    },
                    onComplete: {
                        showingSaveConfirmation = false
                        if let bookId = savedBookId {
                            onBookSaved?(bookId)
                        }
                        onNavigateToLibrary?()
                    }
                )
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: 8) {
            // Left: Navigation buttons
            HStack(spacing: 4) {
                Button {
                    onNavigateToLibrary?()
                } label: {
                    Label("Library", systemImage: "sidebar.left")
                }
                .buttonStyle(.borderless)
                .help("Library")
                
                Button {
                    startNewScan()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("New Scan")
                
                Button {
                    undoLastScan()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.capturedPages.isEmpty)
                .help("Undo Last")
            }
            
            Divider()
                .frame(height: 16)
            
            // Book title - editable
            Button {
                showingTitleEditor = true
            } label: {
                Text(bookTitle)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            // Center: Mode picker
            Picker("Mode", selection: $currentMode) {
                Label("Scan", systemImage: "viewfinder").tag(ScannerMode.scanning)
                Label("Preview", systemImage: "eye").tag(ScannerMode.preview)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .disabled(viewModel.capturedPages.isEmpty && currentMode == .scanning)
            
            Spacer()
            
            // Right: Camera + Done
            HStack(spacing: 12) {
                // Camera selector
                CameraSelector(
                    availableDevices: viewModel.cameraManager.availableDevices,
                    currentDevice: viewModel.cameraManager.currentDevice,
                    isConnected: viewModel.cameraManager.isRunning,
                    onSelectDevice: { device in
                        Task { await viewModel.cameraManager.switchDevice(to: device) }
                    }
                )
                
                // Done button
                Button("Done") {
                    finishAndSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.capturedPages.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContentView: some View {
        ZStack {
            if currentMode == .scanning {
                scannerContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            } else {
                previewContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentMode)
    }
    
    // MARK: - Scanner Content
    
    private var scannerContent: some View {
        ZStack {
            // Camera preview - fills container
            CameraPreview(session: viewModel.cameraManager.session)
                .ignoresSafeArea()
            
            // Document bounds overlay with mask and draggable corners
            GeometryReader { geometry in
                DocumentBoundsOverlay(
                    bounds: viewModel.displayBounds,
                    viewSize: geometry.size,
                    stabilityProgress: viewModel.stabilityProgress,
                    isScanning: viewModel.scanningState == .scanning,
                    statusText: statusText,
                    onCornerDrag: { corner, point in
                        viewModel.updateCorner(corner, to: point)
                    }
                )
            }
            
            // Minimal floating controls
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Left: Scan mode controls (minimal vertical stack)
                    scanControlsPanel
                    
                    Spacer()
                    
                    // Center bottom: Record controls
                    scannerBottomBar
                    
                    Spacer()
                    
                    // Right: Reset button (if needed)
                    if viewModel.manualBoundsAdjustment != nil && !viewModel.isBoundsLocked {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.resetManualBounds()
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Reset Bounds")
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            // Capture success overlay - positioned in corner, non-blocking
            if viewModel.showCaptureSuccess {
                CaptureSuccessOverlay(
                    pageNumber: viewModel.capturedPages.count,
                    capturedImage: viewModel.capturedPages.last?.thumbnail ?? viewModel.capturedPages.last?.displayImage
                )
                .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Scanner Bottom Bar
    
    private var scannerBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.togglePlayPause()
            } label: {
                Label(
                    viewModel.scanningState == .scanning ? "Pause" : "Record",
                    systemImage: viewModel.scanningState == .scanning ? "pause.fill" : "record.circle"
                )
            }
            .buttonStyle(.bordered)
            .tint(viewModel.scanningState == .scanning ? .orange : .red)
            .controlSize(.large)
            .disabled(!viewModel.isCameraReady || viewModel.isOnCooldown)
            
            if !viewModel.isAutoScanEnabled {
                Button {
                    viewModel.capturePhoto()
                } label: {
                    Label("Capture", systemImage: "camera.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!viewModel.isCameraReady || viewModel.isOnCooldown)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: Capsule())
        .shadow(radius: 8, y: 4)
    }
    
    // MARK: - Scan Controls Panel
    
    private var scanControlsPanel: some View {
        VStack(spacing: 6) {
            Toggle(isOn: $viewModel.isBoundsLocked) {
                Label("Lock", systemImage: viewModel.isBoundsLocked ? "lock.fill" : "lock.open")
            }
            .toggleStyle(.button)
            .help(viewModel.isBoundsLocked ? "Unlock Area" : "Lock Area")
            
            Toggle(isOn: $viewModel.isAutoScanEnabled) {
                Label("Auto", systemImage: viewModel.isAutoScanEnabled ? "bolt.fill" : "bolt.slash")
            }
            .toggleStyle(.button)
            .help(viewModel.isAutoScanEnabled ? "Switch to Manual" : "Switch to Auto")
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8, y: 4)
    }
    
    // MARK: - Preview Content (Integrated, not modal)
    
    private var previewContent: some View {
        VStack(spacing: 0) {
            // Page preview area with bounds editing
            GeometryReader { geometry in
                ZStack {
                    // Subtle background
                    Color.primary.opacity(0.02)
                    
                    if viewModel.capturedPages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.image")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(.quaternary)
                            Text("No pages yet")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    } else if previewPageIndex < viewModel.capturedPages.count {
                        let page = viewModel.capturedPages[previewPageIndex]
                        
                        // Main image with bounds overlay
                        ZStack {
                            // Original image (use originalImage to show full frame)
                            if let originalImage = viewModel.imageProcessor.nsImage(from: page.originalImage) {
                                Image(nsImage: originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(previewZoom)
                                    .overlay {
                                        // Bounds overlay for editing
                                        GeometryReader { imageGeometry in
                                            PreviewBoundsOverlay(
                                                bounds: page.bounds,
                                                viewSize: imageGeometry.size,
                                                zoom: previewZoom,
                                                onCornerDrag: { corner, point in
                                                    updatePreviewBounds(corner: corner, point: point, pageIndex: previewPageIndex)
                                                }
                                            )
                                        }
                                    }
                            } else if let image = page.displayImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(previewZoom)
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                        .padding(24)
                    }
                }
            }
            
            // Preview controls bar
            previewControlsBar
        }
    }
    
    // MARK: - Update Preview Bounds
    
    private func updatePreviewBounds(corner: ScannerViewModel.Corner, point: CGPoint, pageIndex: Int) {
        guard pageIndex < viewModel.capturedPages.count else { return }
        
        var page = viewModel.capturedPages[pageIndex]
        guard let currentBounds = page.bounds else { return }
        
        // Clamp to valid range
        let clampedPoint = CGPoint(
            x: max(0.02, min(0.98, point.x)),
            y: max(0.02, min(0.98, point.y))
        )
        
        // Create new bounds with the updated corner
        let newBounds: ImageProcessor.DocumentBounds
        switch corner {
        case .topLeft:
            newBounds = ImageProcessor.DocumentBounds(
                topLeft: clampedPoint,
                topRight: currentBounds.topRight,
                bottomLeft: currentBounds.bottomLeft,
                bottomRight: currentBounds.bottomRight,
                confidence: currentBounds.confidence
            )
        case .topRight:
            newBounds = ImageProcessor.DocumentBounds(
                topLeft: currentBounds.topLeft,
                topRight: clampedPoint,
                bottomLeft: currentBounds.bottomLeft,
                bottomRight: currentBounds.bottomRight,
                confidence: currentBounds.confidence
            )
        case .bottomLeft:
            newBounds = ImageProcessor.DocumentBounds(
                topLeft: currentBounds.topLeft,
                topRight: currentBounds.topRight,
                bottomLeft: clampedPoint,
                bottomRight: currentBounds.bottomRight,
                confidence: currentBounds.confidence
            )
        case .bottomRight:
            newBounds = ImageProcessor.DocumentBounds(
                topLeft: currentBounds.topLeft,
                topRight: currentBounds.topRight,
                bottomLeft: currentBounds.bottomLeft,
                bottomRight: clampedPoint,
                confidence: currentBounds.confidence
            )
        }
        
        // Update bounds and reprocess
        page.bounds = newBounds
        page.processedImage = viewModel.imageProcessor.process(
            image: page.originalImage,
            bounds: newBounds,
            preset: page.preset,
            enhance: true
        )
        page.thumbnail = viewModel.imageProcessor.createHighResThumbnail(
            from: page.processedImage,
            size: NSSize(width: 150, height: 200)
        )
        
        viewModel.capturedPages[pageIndex] = page
    }
    
    // MARK: - Preview Controls Bar
    
    private var previewControlsBar: some View {
        HStack(spacing: 16) {
            // Page navigation
            HStack(spacing: 8) {
                Button {
                    previewPageIndex = max(0, previewPageIndex - 1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(previewPageIndex == 0)
                
                Text("Page \(previewPageIndex + 1) of \(viewModel.capturedPages.count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                
                Button {
                    previewPageIndex = min(viewModel.capturedPages.count - 1, previewPageIndex + 1)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(previewPageIndex >= viewModel.capturedPages.count - 1)
            }
            .disabled(viewModel.capturedPages.isEmpty)
            
            Divider()
                .frame(height: 16)
            
            // Zoom controls
            HStack(spacing: 4) {
                Button {
                    previewZoom = max(0.25, previewZoom - 0.25)
                } label: {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .disabled(previewZoom <= 0.25)
                
                Text("\(Int(previewZoom * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 45)
                
                Button {
                    previewZoom = min(4.0, previewZoom + 0.25)
                } label: {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .disabled(previewZoom >= 4.0)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button(role: .destructive) {
                    if previewPageIndex < viewModel.capturedPages.count {
                        let page = viewModel.capturedPages[previewPageIndex]
                        viewModel.removePage(page)
                        if previewPageIndex >= viewModel.capturedPages.count {
                            previewPageIndex = max(0, viewModel.capturedPages.count - 1)
                        }
                        if viewModel.capturedPages.isEmpty {
                            currentMode = .scanning
                        }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.capturedPages.isEmpty)
                
                Button {
                    currentMode = .scanning
                } label: {
                    Text("Continue Scanning")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
    
    private var statusText: String {
        if viewModel.isBoundsLocked {
            return "Area Locked"
        }
        switch viewModel.scanningState {
        case .scanning:
            if viewModel.stabilityProgress > 0 {
                return "Hold Steady…"
            }
            return "Detecting..."
        case .paused:
            return "Tap to Start"
        case .stopped:
            return "Camera Off"
        }
    }
    
    
    // MARK: - Title Editor Sheet
    
    private var titleEditorSheet: some View {
        Form {
            TextField("Book Title", text: $bookTitle)
        }
        .formStyle(.grouped)
        .frame(width: 300, height: 80)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showingTitleEditor = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    showingTitleEditor = false
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startNewScan() {
        viewModel.clearAllPages()
        viewModel.isBoundsLocked = false
        viewModel.lockedBounds = nil
        viewModel.manualBoundsAdjustment = nil
        bookTitle = "Untitled Book"
        currentMode = .scanning
        previewPageIndex = 0
    }
    
    private func undoLastScan() {
        if let lastPage = viewModel.capturedPages.last {
            viewModel.removePage(lastPage)
        }
    }
    
    private func finishAndSave() {
        showingBookPicker = true
    }
    
    // MARK: - Book Picker Sheet
    
    private var bookPickerSheet: some View {
        VStack(spacing: 16) {
            Text("Save to Book")
                .font(.headline)
            
            if books.isEmpty {
                Text("No books yet. Create one below.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 16)
            } else {
                List(books) { book in
                    Button {
                        saveToBook(book)
                    } label: {
                        HStack {
                            Label(book.title, systemImage: "book.closed.fill")
                            Spacer()
                            Text("\(book.pageCount) pages")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 180)
            }
            
            Divider()
            
            HStack {
                TextField("New Book Title", text: $newBookTitle)
                    .textFieldStyle(.roundedBorder)
                
                Button("Create & Save") {
                    createBookAndSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newBookTitle.isEmpty)
            }
            
            Button("Cancel") {
                showingBookPicker = false
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(20)
        .frame(width: 400)
    }
    
    // MARK: - Save Actions
    
    private func saveToBook(_ book: Book) {
        // Capture cover image before saving (capturedPages will be cleared)
        let coverImage: NSImage?
        if let firstPage = viewModel.capturedPages.first {
            coverImage = firstPage.displayImage ?? firstPage.thumbnail
        } else {
            coverImage = nil
        }
        let pageCount = viewModel.capturedPages.count
        let title = book.title
        let bookId = book.id
        
        Task {
            do {
                try await viewModel.saveToBook(book, modelContext: modelContext)
                showingBookPicker = false
                
                // Show save confirmation with animation
                savedBookCover = coverImage
                savedBookTitle = title
                savedBookPageCount = pageCount
                savedBookId = bookId
                
                // Trigger library icon pop animation
                onBookArrived?()
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showingSaveConfirmation = true
                }
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func createBookAndSave() {
        let book = Book(title: newBookTitle.isEmpty ? bookTitle : newBookTitle)
        modelContext.insert(book)
        newBookTitle = ""
        saveToBook(book)
    }
}

// MARK: - Preview Bounds Overlay

/// Overlay for editing document bounds in preview mode
private struct PreviewBoundsOverlay: View {
    let bounds: ImageProcessor.DocumentBounds?
    let viewSize: CGSize
    let zoom: Double
    let onCornerDrag: (ScannerViewModel.Corner, CGPoint) -> Void
    
    @State private var isDragging = false
    
    private let cornerSize: CGFloat = 24
    private let lineWidth: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            if let bounds = bounds {
                let size = geometry.size
                
                // Convert normalized coordinates to view coordinates
                let topLeft = CGPoint(x: bounds.topLeft.x * size.width, y: (1 - bounds.topLeft.y) * size.height)
                let topRight = CGPoint(x: bounds.topRight.x * size.width, y: (1 - bounds.topRight.y) * size.height)
                let bottomLeft = CGPoint(x: bounds.bottomLeft.x * size.width, y: (1 - bounds.bottomLeft.y) * size.height)
                let bottomRight = CGPoint(x: bounds.bottomRight.x * size.width, y: (1 - bounds.bottomRight.y) * size.height)
                
                ZStack {
                    // Dimmed overlay outside bounds
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: size))
                        path.move(to: topLeft)
                        path.addLine(to: topRight)
                        path.addLine(to: bottomRight)
                        path.addLine(to: bottomLeft)
                        path.closeSubpath()
                    }
                    .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
                    
                    // Border lines
                    Path { path in
                        path.move(to: topLeft)
                        path.addLine(to: topRight)
                        path.addLine(to: bottomRight)
                        path.addLine(to: bottomLeft)
                        path.closeSubpath()
                    }
                    .stroke(Color.accentColor, lineWidth: lineWidth)
                    
                    // Draggable corner handles
                    cornerHandle(at: topLeft, corner: .topLeft, size: size)
                    cornerHandle(at: topRight, corner: .topRight, size: size)
                    cornerHandle(at: bottomLeft, corner: .bottomLeft, size: size)
                    cornerHandle(at: bottomRight, corner: .bottomRight, size: size)
                }
            }
        }
        .allowsHitTesting(true)
    }
    
    @ViewBuilder
    private func cornerHandle(at point: CGPoint, corner: ScannerViewModel.Corner, size: CGSize) -> some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: cornerSize, height: cornerSize)
            .overlay(
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .position(point)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPoint = CGPoint(
                            x: value.location.x / size.width,
                            y: 1 - (value.location.y / size.height)
                        )
                        onCornerDrag(corner, newPoint)
                    }
            )
    }
}

// MARK: - Flying Book Save Animation (Instagram-style)

/// Instagram-inspired "send" animation - book flies to library icon
private struct BookSaveConfirmationOverlay: View {
    let coverImage: NSImage?
    let bookTitle: String
    let pageCount: Int
    let onBookArrived: () -> Void
    let onComplete: () -> Void
    
    // Animation states
    @State private var backdropOpacity: Double = 0
    @State private var bookScale: CGFloat = 0.5
    @State private var bookOpacity: Double = 0
    @State private var bookPosition: CGPoint = .zero
    @State private var bookRotation: Double = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var labelOpacity: Double = 0
    @State private var labelOffset: CGFloat = 20
    @State private var isFlying = false
    @State private var trailPositions: [CGPoint] = []
    
    // Target position for the library icon (top-left of window, accounting for toolbar)
    private let libraryIconTarget = CGPoint(x: 120, y: 52)
    
    var body: some View {
        GeometryReader { geometry in
            let centerPosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2 - 40)
            
            ZStack {
                // Backdrop with blur
                Color.black.opacity(backdropOpacity * 0.55)
                    .ignoresSafeArea()
                
                // Motion trail (visible during flight)
                if isFlying {
                    ForEach(0..<6, id: \.self) { i in
                        let progress = Double(i) / 6.0
                        let trailPos = interpolatePosition(
                            from: centerPosition,
                            to: libraryIconTarget,
                            progress: progress * 0.8
                        )
                        
                        Circle()
                            .fill(Color(hex: "34C759").opacity(0.4 - progress * 0.3))
                            .frame(width: 12 - CGFloat(i) * 1.5, height: 12 - CGFloat(i) * 1.5)
                            .position(trailPos)
                            .blur(radius: CGFloat(i) * 0.5)
                    }
                }
                
                // Main book card
                VStack(spacing: 0) {
                    ZStack {
                        // Book cover
                        bookCover
                            .frame(width: isFlying ? 40 : 150, height: isFlying ? 52 : 195)
                        
                        // Success checkmark badge
                        if !isFlying {
                            Circle()
                                .fill(Color(hex: "34C759"))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .shadow(color: Color(hex: "34C759").opacity(0.6), radius: 10, y: 3)
                                .scaleEffect(checkmarkScale)
                                .opacity(checkmarkOpacity)
                                .offset(x: 65, y: -85)
                        }
                    }
                    
                    // Label below book (hidden during flight)
                    if !isFlying {
                        VStack(spacing: 5) {
                            Text("Saved!")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("\(pageCount) \(pageCount == 1 ? "page" : "pages")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.top, 18)
                        .opacity(labelOpacity)
                        .offset(y: labelOffset)
                    }
                }
                .scaleEffect(bookScale)
                .opacity(bookOpacity)
                .position(isFlying ? bookPosition : centerPosition)
                .rotation3DEffect(
                    .degrees(bookRotation),
                    axis: (x: 0.1, y: 1, z: 0.05),
                    perspective: 0.4
                )
            }
        }
        .onAppear {
            runFlyingAnimation()
        }
    }
    
    private var bookCover: some View {
        Group {
            if let cover = coverImage {
                Image(nsImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: isFlying ? 4 : 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: isFlying ? 4 : 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: isFlying ? 1 : 1.5)
                    )
                    .shadow(color: .black.opacity(isFlying ? 0.3 : 0.5), radius: isFlying ? 8 : 18, y: isFlying ? 3 : 8)
            } else {
                RoundedRectangle(cornerRadius: isFlying ? 4 : 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "5B8DEF"), Color(hex: "3D5A99")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        VStack(spacing: isFlying ? 2 : 8) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: isFlying ? 12 : 36, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            if !isFlying {
                                Text(bookTitle)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: isFlying ? 4 : 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isFlying ? 0.3 : 0.5), radius: isFlying ? 8 : 18, y: isFlying ? 3 : 8)
            }
        }
    }
    
    private func interpolatePosition(from: CGPoint, to: CGPoint, progress: Double) -> CGPoint {
        // Curved path with easing
        let curveHeight: CGFloat = -80 // Arc upward
        let x = from.x + (to.x - from.x) * progress
        let linearY = from.y + (to.y - from.y) * progress
        let curveOffset = curveHeight * sin(progress * .pi) // Parabolic arc
        return CGPoint(x: x, y: linearY + curveOffset)
    }
    
    private func runFlyingAnimation() {
        // Phase 1: Fade in backdrop and book with bounce
        withAnimation(.easeOut(duration: 0.2)) {
            backdropOpacity = 1.0
            bookOpacity = 1.0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            bookScale = 1.0
        }
        
        // Phase 2: Pop in checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.25)) {
                labelOpacity = 1.0
                labelOffset = 0
            }
        }
        
        // Phase 3: Brief pause, then fly to library icon!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            // Hide label and checkmark
            withAnimation(.easeIn(duration: 0.15)) {
                labelOpacity = 0
                checkmarkOpacity = 0
            }
            
            // Start the flight
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFlying = true
                
                // Animate position along curved path to library icon
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.55)) {
                    bookPosition = libraryIconTarget
                    bookScale = 0.25
                    bookRotation = -20
                }
                
                // Fade backdrop
                withAnimation(.easeOut(duration: 0.4)) {
                    backdropOpacity = 0
                }
                
                // Trigger library icon pop when book arrives
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    onBookArrived()
                }
                
                // Fade out book as it "enters" the icon
                withAnimation(.easeOut(duration: 0.2).delay(0.4)) {
                    bookOpacity = 0
                }
            }
        }
        
        // Phase 4: Complete transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            onComplete()
        }
    }
}

#Preview {
    ScannerView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}

