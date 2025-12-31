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

/// Main scanning view with camera preview and controls
/// Redesigned with native macOS styling and refined visual design
struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showingBookPicker = false
    @State private var showingPreview = false
    @State private var showingTitleEditor = false
    @State private var newBookTitle = ""
    @State private var currentMode: ScannerMode = .scanning
    @State private var bookTitle: String = "Untitled Book"
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    
    // Callback to navigate to library
    var onNavigateToLibrary: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            ScannerToolbar(
                currentMode: currentMode,
                bookTitle: bookTitle,
                canUndo: !viewModel.capturedPages.isEmpty,
                hasScannedPages: !viewModel.capturedPages.isEmpty,
                availableDevices: viewModel.cameraManager.availableDevices,
                currentDevice: viewModel.cameraManager.currentDevice,
                isCameraConnected: viewModel.cameraManager.isRunning,
                onLibrary: { onNavigateToLibrary?() },
                onNewScan: { startNewScan() },
                onEditTitle: { showingTitleEditor = true },
                onScanMode: { currentMode = .scanning },
                onPreviewMode: { 
                    currentMode = .preview
                    showingPreview = true
                },
                onUndo: { undoLastScan() },
                onDone: { finishAndSave() },
                onSelectCamera: { device in
                    Task { await viewModel.cameraManager.switchDevice(to: device) }
                }
            )
            
            // Main content based on mode
            if currentMode == .scanning {
                scannerContent
            }
            
            // Bottom thumbnail strip
            ScannedPagesStrip(
                pages: viewModel.capturedPages,
                coverImage: nil,
                onDeletePage: { page in viewModel.removePage(page) },
                onTapPage: { _ in
                    currentMode = .preview
                    showingPreview = true
                }
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await viewModel.startScanning()
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
        .sheet(isPresented: $showingPreview) {
            PreviewView(viewModel: viewModel, isPresented: $showingPreview)
        }
        .sheet(isPresented: $showingTitleEditor) {
            titleEditorSheet
        }
    }
    
    // MARK: - Scanner Content
    
    private var scannerContent: some View {
        ZStack {
            // Camera preview with rounded corners
            CameraPreview(session: viewModel.cameraManager.session)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(20)
            
            // Document bounds overlay with status text
            GeometryReader { geometry in
                DocumentBoundsOverlay(
                    bounds: viewModel.currentBounds,
                    viewSize: CGSize(
                        width: geometry.size.width - 40,
                        height: geometry.size.height - 40
                    ),
                    stabilityProgress: viewModel.stabilityProgress,
                    isScanning: viewModel.scanningState == .scanning,
                    statusText: statusText
                )
                .offset(x: 20, y: 20)
            }
            
            // Camera selector in top-right of camera view
            VStack {
                HStack {
                    Spacer()
                    CameraSelector(
                        availableDevices: viewModel.cameraManager.availableDevices,
                        currentDevice: viewModel.cameraManager.currentDevice,
                        isConnected: viewModel.cameraManager.isRunning,
                        onSelectDevice: { device in
                            Task { await viewModel.cameraManager.switchDevice(to: device) }
                        }
                    )
                    .padding(28)
                }
                Spacer()
            }
            
            // Processing indicator
            if viewModel.isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Processing...")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
            }
            
            // Capture success overlay
            if viewModel.showCaptureSuccess {
                CaptureSuccessOverlay(pageNumber: viewModel.capturedPages.count)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    ))
            }
            
            // Record button at bottom center
            VStack {
                Spacer()
                
                RecordButton(
                    isRecording: viewModel.scanningState == .scanning,
                    isEnabled: viewModel.cameraManager.isRunning,
                    action: { toggleRecording() }
                )
                .padding(.bottom, 28)
            }
        }
    }
    
    private var statusText: String {
        switch viewModel.scanningState {
        case .scanning:
            if viewModel.stabilityProgress > 0 {
                return "Hold Steady…"
            }
            return "Scanning…"
        case .paused:
            return "Paused"
        case .stopped:
            return "Stopped"
        }
    }
    
    // MARK: - Title Editor Sheet
    
    private var titleEditorSheet: some View {
        VStack(spacing: 24) {
            Text("Edit Book Title")
                .font(.headline)
            
            TextField("Book Title", text: $bookTitle)
                .textFieldStyle(.plain)
                .font(.system(.body))
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .frame(width: 300)
            
            HStack(spacing: 12) {
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
        .padding(28)
        .frame(minWidth: 360)
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if viewModel.scanningState == .scanning {
            viewModel.togglePlayPause()
        } else if viewModel.scanningState == .paused {
            viewModel.togglePlayPause()
        } else {
            Task { await viewModel.startScanning() }
        }
    }
    
    private func startNewScan() {
        viewModel.clearAllPages()
        bookTitle = "Untitled Book"
        currentMode = .scanning
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
        VStack(spacing: 20) {
            Text("Save to Book")
                .font(.headline)
            
            if books.isEmpty {
                Text("No books yet. Create one below.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(books) { book in
                            Button {
                                saveToBook(book)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "book.closed.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 18))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(book.title)
                                            .foregroundStyle(.primary)
                                        Text("\(book.pageCount) pages")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(height: 180)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Create New Book")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    TextField("New Book Title", text: $newBookTitle)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    
                    Button("Create") {
                        createBookAndSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newBookTitle.isEmpty)
                }
            }
            
            Button("Cancel") {
                showingBookPicker = false
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(24)
        .frame(width: 420)
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

#Preview {
    ScannerView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
