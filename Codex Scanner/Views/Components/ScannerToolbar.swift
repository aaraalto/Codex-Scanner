//
//  ScannerToolbar.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI
import AVFoundation

/// Mode for the scanner view
enum ScannerMode {
    case scanning
    case preview
}

/// Main toolbar for the scanner view with native macOS styling
/// Contains: library, new scan, book title, scan/preview modes, undo, camera selector, done
struct ScannerToolbar: View {
    // State
    let currentMode: ScannerMode
    let bookTitle: String
    let canUndo: Bool
    let hasScannedPages: Bool
    
    // Camera state
    let availableDevices: [AVCaptureDevice]
    let currentDevice: AVCaptureDevice?
    let isCameraConnected: Bool
    
    // Actions
    let onLibrary: () -> Void
    let onNewScan: () -> Void
    let onEditTitle: () -> Void
    let onScanMode: () -> Void
    let onPreviewMode: () -> Void
    let onUndo: () -> Void
    let onDone: () -> Void
    let onSelectCamera: (AVCaptureDevice) -> Void
    
    // Design constants
    private let toolbarHeight: CGFloat = 52
    private let horizontalPadding: CGFloat = 16
    
    var body: some View {
        HStack(spacing: 16) {
            // Left section: Library + New Scan
            leftSection
            
            Divider()
                .frame(height: 24)
            
            // Center section: Book title + Mode toggles + Undo
            centerSection
            
            Spacer()
            
            // Right section: Done
            rightSection
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: toolbarHeight)
        .background(.bar)
    }
    
    // MARK: - Left Section
    
    private var leftSection: some View {
        HStack(spacing: 4) {
            Button(action: onLibrary) {
                Label("Library", systemImage: "rectangle.stack")
            }
            .buttonStyle(.borderless)
            .help("Open Library")
            
            Button(action: onNewScan) {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .help("Start New Scan")
        }
    }
    
    // MARK: - Center Section
    
    private var centerSection: some View {
        HStack(spacing: 16) {
            // Book title pill
            BookTitlePill(
                title: bookTitle,
                onTap: onEditTitle
            )
            
            // Mode toggle using native Picker
            Picker("Mode", selection: .init(
                get: { currentMode },
                set: { mode in
                    if mode == .scanning {
                        onScanMode()
                    } else {
                        onPreviewMode()
                    }
                }
            )) {
                Label("Scan", systemImage: "doc.viewfinder")
                    .tag(ScannerMode.scanning)
                Label("Preview", systemImage: "eye")
                    .tag(ScannerMode.preview)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .labelsHidden()
            
            // Undo button
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .disabled(!canUndo)
            .help("Undo Last Scan")
        }
    }
    
    // MARK: - Right Section
    
    private var rightSection: some View {
        HStack(spacing: 12) {
            // Camera selector
            CameraSelector(
                availableDevices: availableDevices,
                currentDevice: currentDevice,
                isConnected: isCameraConnected,
                onSelectDevice: onSelectCamera
            )
            
            // Done button
            Button(action: onDone) {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!hasScannedPages)
        }
    }
}

#Preview {
    VStack {
        ScannerToolbar(
            currentMode: .scanning,
            bookTitle: "The Great Gatsby",
            canUndo: true,
            hasScannedPages: true,
            availableDevices: [],
            currentDevice: nil,
            isCameraConnected: true,
            onLibrary: {},
            onNewScan: {},
            onEditTitle: {},
            onScanMode: {},
            onPreviewMode: {},
            onUndo: {},
            onDone: {},
            onSelectCamera: { _ in }
        )
        
        Spacer()
    }
    .frame(width: 900, height: 400)
}
