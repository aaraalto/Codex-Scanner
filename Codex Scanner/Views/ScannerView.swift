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
    
    // Callback to navigate to library
    var onNavigateToLibrary: (() -> Void)?
    
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
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            
            // Subtle radial gradient for depth
            RadialGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor).opacity(0.3),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 800
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: 20) {
            // Left: Navigation
            HStack(spacing: 10) {
                ToolbarButton(icon: "rectangle.stack.fill", tooltip: "Library") {
                    onNavigateToLibrary?()
                }
                
                ToolbarButton(icon: "plus", tooltip: "New Scan") {
                    startNewScan()
                }
            }
            
            Divider()
                .frame(height: 32)
                .opacity(0.2)
            
            // Book title
            BookTitlePill(title: bookTitle, onTap: { showingTitleEditor = true })
            
            Spacer()
            
            // Center: Mode toggle
            HStack(spacing: 4) {
                ModeButton(
                    icon: "viewfinder",
                    label: "Scan",
                    isActive: currentMode == .scanning
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        currentMode = .scanning
                    }
                }
                
                ModeButton(
                    icon: "eye",
                    label: "Preview",
                    isActive: currentMode == .preview
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        currentMode = .preview
                    }
                }
                .disabled(viewModel.capturedPages.isEmpty)
                .opacity(viewModel.capturedPages.isEmpty ? 0.5 : 1)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            Spacer()
            
            // Right: Actions
            HStack(spacing: 14) {
                // Undo button
                ToolbarButton(
                    icon: "arrow.uturn.backward",
                    tooltip: "Undo Last Scan",
                    disabled: viewModel.capturedPages.isEmpty
                ) {
                    undoLastScan()
                }
                
                // Camera selector
                CameraSelector(
                    availableDevices: viewModel.cameraManager.availableDevices,
                    currentDevice: viewModel.cameraManager.currentDevice,
                    isConnected: viewModel.cameraManager.isRunning,
                    onSelectDevice: { device in
                        Task { await viewModel.cameraManager.switchDevice(to: device) }
                    }
                )
                
                // Cooldown indicator
                if viewModel.isOnCooldown {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Processing...")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                }
                
                // Done button
                Button {
                    finishAndSave()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Done")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .controlSize(.large)
                .disabled(viewModel.capturedPages.isEmpty)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.white.opacity(0.08)),
            alignment: .bottom
        )
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
            
            // Document bounds overlay with draggable corners
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
            
            // Floating controls overlay
            VStack {
                // Top bar with controls
                HStack(alignment: .top) {
                    // Scan controls (left side)
                    scanControlsPanel
                    
                    Spacer()
                    
                    // Reset bounds button (if manually adjusted and not locked)
                    if viewModel.manualBoundsAdjustment != nil && !viewModel.isBoundsLocked {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.resetManualBounds()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
                
                Spacer()
                
                // Bottom controls bar
                scannerBottomBar
            }
            
            // Processing indicator
            if viewModel.isProcessing {
                processingOverlay
            }
            
            // Capture success overlay
            if viewModel.showCaptureSuccess {
                CaptureSuccessOverlay(pageNumber: viewModel.capturedPages.count)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    ))
            }
        }
    }
    
    // MARK: - Scanner Bottom Bar
    
    private var scannerBottomBar: some View {
        HStack(spacing: 20) {
            // Status text
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.scanningState == .scanning ? Color.red : Color.secondary)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            
            Spacer()
            
            // Play/Pause button
            RecordButton(
                isRecording: viewModel.scanningState == .scanning,
                isEnabled: viewModel.isCameraReady && !viewModel.isOnCooldown,
                action: { viewModel.togglePlayPause() }
            )
            
            Spacer()
            
            // Manual capture button (when not auto-scanning)
            if !viewModel.isAutoScanEnabled {
                Button {
                    viewModel.capturePhoto()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Capture")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isCameraReady || viewModel.isOnCooldown)
            } else {
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 100)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            .regularMaterial
                .opacity(0.95),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: -5)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Scan Controls Panel
    
    private var scanControlsPanel: some View {
        HStack(spacing: 8) {
            // Lock Bounds Toggle
            CompactControlButton(
                icon: viewModel.isBoundsLocked ? "lock.fill" : "lock.open",
                isActive: viewModel.isBoundsLocked,
                activeColor: .orange,
                tooltip: viewModel.isBoundsLocked ? "Unlock Area" : "Lock Area"
            ) {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.toggleBoundsLock()
                }
            }
            
            // Auto-scan toggle
            CompactControlButton(
                icon: viewModel.isAutoScanEnabled ? "bolt.fill" : "bolt.slash",
                isActive: viewModel.isAutoScanEnabled,
                activeColor: .green,
                tooltip: viewModel.isAutoScanEnabled ? "Switch to Manual" : "Switch to Auto"
            ) {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.isAutoScanEnabled.toggle()
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
    
    // MARK: - Preview Content (Integrated, not modal)
    
    private var previewContent: some View {
        VStack(spacing: 0) {
            // Page preview area
            GeometryReader { geometry in
                ZStack {
                    if viewModel.capturedPages.isEmpty {
                        ContentUnavailableView(
                            "No Pages Yet",
                            systemImage: "doc.text.image",
                            description: Text("Scan some pages to preview")
                        )
                    } else if previewPageIndex < viewModel.capturedPages.count {
                        let page = viewModel.capturedPages[previewPageIndex]
                        
                        ScrollView([.horizontal, .vertical], showsIndicators: false) {
                            if let image = page.displayImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(previewZoom)
                                    .frame(
                                        minWidth: geometry.size.width * 0.5,
                                        minHeight: geometry.size.height * 0.5
                                    )
                            } else {
                                ProgressView()
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 25, y: 10)
                        .padding(28)
                    }
                }
            }
            
            // Preview controls bar
            previewControlsBar
        }
    }
    
    // MARK: - Preview Controls Bar
    
    private var previewControlsBar: some View {
        HStack(spacing: 28) {
            // Page navigation
            HStack(spacing: 18) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        previewPageIndex = max(0, previewPageIndex - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.bordered)
                .disabled(previewPageIndex == 0)
                
                Text("Page \(previewPageIndex + 1) of \(viewModel.capturedPages.count)")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 150)
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        previewPageIndex = min(viewModel.capturedPages.count - 1, previewPageIndex + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.bordered)
                .disabled(previewPageIndex >= viewModel.capturedPages.count - 1)
            }
            .disabled(viewModel.capturedPages.isEmpty)
            
            Divider()
                .frame(height: 32)
                .opacity(0.3)
            
            // Zoom controls
            HStack(spacing: 14) {
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        previewZoom = max(0.25, previewZoom - 0.25)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                }
                .buttonStyle(.borderless)
                .disabled(previewZoom <= 0.25)
                
                Text("\(Int(previewZoom * 100))%")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 54)
                
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        previewZoom = min(4.0, previewZoom + 0.25)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                }
                .buttonStyle(.borderless)
                .disabled(previewZoom >= 4.0)
                
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        previewZoom = 1.0
                    }
                } label: {
                    Text("Fit")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Spacer()
            
            // Confirm and continue
            HStack(spacing: 16) {
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
                    Label("Delete Page", systemImage: "trash")
                }
                .disabled(viewModel.capturedPages.isEmpty)
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        currentMode = .scanning
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 14, weight: .medium))
                        Text("Continue Scanning")
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.white.opacity(0.1)),
            alignment: .top
        )
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            
            Text("Processing...")
                .font(.system(.headline, design: .rounded, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 35, y: 12)
    }
    
    private var statusText: String {
        if viewModel.isBoundsLocked {
            return "Area Locked"
        }
        switch viewModel.scanningState {
        case .scanning:
            if viewModel.isOnCooldown {
                return "Preparing..."
            } else if viewModel.stabilityProgress > 0 {
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
        VStack(spacing: 28) {
            Text("Edit Book Title")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            
            TextField("Book Title", text: $bookTitle)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .frame(width: 320)
            
            HStack(spacing: 14) {
                Button("Cancel") {
                    showingTitleEditor = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Save") {
                    showingTitleEditor = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(32)
        .frame(minWidth: 380)
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
        VStack(spacing: 24) {
            Text("Save to Book")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            
            if books.isEmpty {
                Text("No books yet. Create one below.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(books) { book in
                            Button {
                                saveToBook(book)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "book.closed.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 20))
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(book.title)
                                            .foregroundStyle(.primary)
                                            .font(.system(.body, design: .rounded, weight: .medium))
                                        Text("\(book.pageCount) pages")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .frame(height: 200)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Create New Book")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 14) {
                    TextField("New Book Title", text: $newBookTitle)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                        .padding(14)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    
                    Button("Create") {
                        createBookAndSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(newBookTitle.isEmpty)
                }
            }
            
            Button("Cancel") {
                showingBookPicker = false
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(28)
        .frame(width: 450)
    }
    
    // MARK: - Save Actions
    
    private func saveToBook(_ book: Book) {
        Task {
            do {
                try await viewModel.saveToBook(book, modelContext: modelContext)
                showingBookPicker = false
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func createBookAndSave() {
        let book = Book(title: newBookTitle)
        modelContext.insert(book)
        newBookTitle = ""
        saveToBook(book)
    }
}

// MARK: - Toolbar Button Component

private struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    var disabled: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHovered ? 0.15 : 0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .onHover { hovering in
            guard !disabled else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Mode Button Component

private struct ModeButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : (isHovered ? .primary : .secondary))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? Color.accentColor : (isHovered ? Color.white.opacity(0.08) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Compact Control Button Component

private struct CompactControlButton: View {
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? activeColor : (isHovered ? .primary : .secondary))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? activeColor.opacity(0.2) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    ScannerView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
