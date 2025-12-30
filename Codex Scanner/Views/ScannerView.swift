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
struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showingBookPicker = false
    @State private var showingPreview = false
    @State private var newBookTitle = ""
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    
    // Design constants
    private let accentGradient = LinearGradient(
        colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        HSplitView {
            // Camera preview area
            cameraSection
                .frame(minWidth: 550)
            
            // Captured pages strip
            capturedPagesSection
                .frame(minWidth: 220, maxWidth: 320)
        }
        .background(Color(hex: "0F0F14"))
        .toolbar {
            toolbarContent
        }
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
    }
    
    // MARK: - Camera Section
    
    private var cameraSection: some View {
        ZStack {
            // Dark background
            Color(hex: "0F0F14")
            
            // Camera preview with rounded corners
            CameraPreview(session: viewModel.cameraManager.session)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(16)
            
            // Document bounds overlay
            GeometryReader { geometry in
                DocumentBoundsOverlay(
                    bounds: viewModel.currentBounds,
                    viewSize: CGSize(
                        width: geometry.size.width - 32,
                        height: geometry.size.height - 32
                    ),
                    stabilityProgress: viewModel.stabilityProgress,
                    isScanning: viewModel.scanningState == .scanning
                )
                .offset(x: 16, y: 16)
            }
            
            // Processing indicator
            if viewModel.isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(24)
                .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
            }
            
            // Capture success overlay
            if viewModel.showCaptureSuccess {
                CaptureSuccessOverlay(pageNumber: viewModel.capturedPages.count)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // Bottom controls
            VStack {
                // Top status bar
                statusBar
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Bottom control panel
                controlPanel
                    .padding(.bottom, 24)
                    .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack {
            // Scanning state indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.scanningState.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: viewModel.scanningState.color.opacity(0.5), radius: 4)
                
                Text(viewModel.scanningState.rawValue)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.5), in: Capsule())
            
            Spacer()
            
            // Auto-scan indicator
            if viewModel.isAutoScanEnabled && viewModel.scanningState == .scanning {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text("Auto")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.5), in: Capsule())
            }
            
            // Page counter
            if !viewModel.capturedPages.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .font(.caption2)
                    Text("\(viewModel.capturedPages.count)")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accentGradient, in: Capsule())
            }
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        HStack(spacing: 0) {
            // Left controls
            HStack(spacing: 16) {
                // Stop button
                ControlButton(
                    icon: "stop.fill",
                    label: "Stop",
                    isActive: viewModel.scanningState == .stopped,
                    color: .red
                ) {
                    viewModel.stopScanning()
                }
                
                // Play/Pause button
                ControlButton(
                    icon: viewModel.scanningState == .scanning ? "pause.fill" : "play.fill",
                    label: viewModel.scanningState == .scanning ? "Pause" : "Play",
                    isActive: viewModel.scanningState != .stopped,
                    color: viewModel.scanningState == .scanning ? .orange : .green
                ) {
                    if viewModel.scanningState == .stopped {
                        Task { await viewModel.startScanning() }
                    } else {
                        viewModel.togglePlayPause()
                    }
                }
            }
            
            Spacer()
            
            // Center - Capture button
            captureButton
            
            Spacer()
            
            // Right controls
            HStack(spacing: 16) {
                // Auto-scan toggle
                ControlButton(
                    icon: "bolt.fill",
                    label: "Auto",
                    isActive: viewModel.isAutoScanEnabled,
                    color: .yellow
                ) {
                    viewModel.isAutoScanEnabled.toggle()
                }
                
                // Filter preset
                Menu {
                    ForEach(ImageProcessor.FilterPreset.allCases) { preset in
                        Button {
                            viewModel.selectedPreset = preset
                        } label: {
                            HStack {
                                Text(preset.rawValue)
                                if viewModel.selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.filters")
                            .font(.system(size: 18))
                        Text("Filter")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
    }
    
    // MARK: - Capture Button
    
    private var captureButton: some View {
        Button(action: { viewModel.capturePhoto() }) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 72, height: 72)
                
                // Inner circle
                Circle()
                    .fill(.white)
                    .frame(width: 58, height: 58)
                
                // Stability progress ring
                if viewModel.stabilityProgress > 0 {
                    Circle()
                        .trim(from: 0, to: viewModel.stabilityProgress)
                        .stroke(
                            accentGradient,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.scanningState == .stopped || !viewModel.cameraManager.isRunning)
        .scaleEffect(viewModel.scanningState == .stopped ? 0.9 : 1.0)
        .animation(.spring(response: 0.3), value: viewModel.scanningState)
    }
    
    // MARK: - Captured Pages Section
    
    private var capturedPagesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Scanned Pages")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(viewModel.capturedPages.count)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentGradient, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Pages list
            if viewModel.capturedPages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No pages yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Capture documents to see them here")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(viewModel.capturedPages.enumerated()), id: \.element.id) { index, page in
                                CapturedPageRow(
                                    page: page,
                                    pageNumber: index + 1,
                                    isHighlighted: viewModel.lastCapturedPageId == page.id,
                                    onDelete: { viewModel.removePage(page) }
                                )
                                .id(page.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                                    removal: .opacity
                                ))
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: viewModel.lastCapturedPageId) { _, newId in
                        if let newId = newId {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(newId, anchor: .top)
                            }
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Action buttons
            VStack(spacing: 10) {
                // Preview button
                Button {
                    showingPreview = true
                } label: {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("Preview Document")
                    }
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.capturedPages.isEmpty)
                
                // Save button
                Button {
                    showingBookPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Save to Book")
                    }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(accentGradient, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.capturedPages.isEmpty)
            }
            .padding(12)
        }
        .background(Color(hex: "1A1A24"))
    }
    
    // MARK: - Book Picker Sheet
    
    private var bookPickerSheet: some View {
        VStack(spacing: 20) {
            Text("Save to Book")
                .font(.headline)
            
            if books.isEmpty {
                Text("No books yet. Create one below.")
                    .foregroundStyle(.secondary)
            } else {
                List(books) { book in
                    Button {
                        saveToBook(book)
                    } label: {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(book.title)
                                Text("\(book.pageCount) pages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 200)
            }
            
            Divider()
            
            HStack {
                TextField("New Book Title", text: $newBookTitle)
                    .textFieldStyle(.roundedBorder)
                
                Button("Create & Save") {
                    createBookAndSave()
                }
                .disabled(newBookTitle.isEmpty)
            }
            
            Button("Cancel") {
                showingBookPicker = false
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                ForEach(viewModel.cameraManager.availableDevices, id: \.uniqueID) { device in
                    Button {
                        Task {
                            await viewModel.cameraManager.switchDevice(to: device)
                        }
                    } label: {
                        HStack {
                            Text(device.localizedName)
                            if device.uniqueID == viewModel.cameraManager.currentDevice?.uniqueID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Camera", systemImage: "camera")
            }
        }
        
        ToolbarItem(placement: .status) {
            if let device = viewModel.cameraManager.currentDevice {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.cameraManager.isRunning ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(device.localizedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Actions
    
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

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isActive ? color : .white.opacity(0.5))
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? color.opacity(0.2) : .white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? color.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Capture Success Overlay

struct CaptureSuccessOverlay: View {
    let pageNumber: Int
    @State private var showCheckmark = false
    @State private var showText = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Success checkmark with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "059669")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "10B981").opacity(0.5), radius: 20)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(showCheckmark ? 1 : 0)
            }
            
            VStack(spacing: 8) {
                Text("Page \(pageNumber) Captured!")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 14, weight: .medium))
                    Text("Turn the page")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15), in: Capsule())
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 10)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 30)
        )
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showText = true
            }
        }
    }
}

// MARK: - Captured Page Row

struct CapturedPageRow: View {
    let page: ScannerViewModel.CapturedPage
    let pageNumber: Int
    var isHighlighted: Bool = false
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Page number
            Text("\(pageNumber)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(isHighlighted ? Color(hex: "10B981") : .white.opacity(0.5))
                .frame(width: 24)
            
            // Thumbnail
            if let thumbnail = page.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 65)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: isHighlighted ? Color(hex: "10B981").opacity(0.5) : .black.opacity(0.3), radius: isHighlighted ? 8 : 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isHighlighted ? Color(hex: "10B981") : .clear, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 50, height: 65)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(page.preset.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                
                if let bounds = page.bounds {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("\(Int(bounds.confidence * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(8)
                    .background(Color.red.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? Color(hex: "10B981").opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHighlighted ? Color(hex: "10B981").opacity(0.5) : .clear, lineWidth: 1)
        )
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)
    }
}

// MARK: - Document Bounds Overlay (Updated)

struct DocumentBoundsOverlay: View {
    let bounds: ImageProcessor.DocumentBounds?
    let viewSize: CGSize
    let stabilityProgress: Double
    let isScanning: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if let bounds = bounds {
                let size = viewSize
                
                // Convert normalized coordinates to view coordinates
                let topLeft = CGPoint(
                    x: bounds.topLeft.x * size.width,
                    y: (1 - bounds.topLeft.y) * size.height
                )
                let topRight = CGPoint(
                    x: bounds.topRight.x * size.width,
                    y: (1 - bounds.topRight.y) * size.height
                )
                let bottomLeft = CGPoint(
                    x: bounds.bottomLeft.x * size.width,
                    y: (1 - bounds.bottomLeft.y) * size.height
                )
                let bottomRight = CGPoint(
                    x: bounds.bottomRight.x * size.width,
                    y: (1 - bounds.bottomRight.y) * size.height
                )
                
                // Document outline
                Path { path in
                    path.move(to: topLeft)
                    path.addLine(to: topRight)
                    path.addLine(to: bottomRight)
                    path.addLine(to: bottomLeft)
                    path.closeSubpath()
                }
                .stroke(
                    isScanning ? Color(hex: "4F46E5") : Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color(hex: "4F46E5").opacity(isScanning ? 0.5 : 0), radius: 8)
                
                // Corner indicators
                ForEach(Array([topLeft, topRight, bottomLeft, bottomRight].enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(isScanning ? Color(hex: "4F46E5") : .white.opacity(0.8))
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .position(point)
                }
                
                // Stability indicator
                if stabilityProgress > 0 && isScanning {
                    let center = CGPoint(
                        x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4,
                        y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4
                    )
                    
                    Circle()
                        .trim(from: 0, to: stabilityProgress)
                        .stroke(Color(hex: "4F46E5"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .position(center)
                        .shadow(color: Color(hex: "4F46E5").opacity(0.5), radius: 8)
                }
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ScannerView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
