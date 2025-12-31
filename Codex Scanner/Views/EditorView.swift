//
//  EditorView.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI
import AppKit

/// View for editing individual scanned pages with native macOS styling
struct EditorView: View {
    let page: Page
    @State private var currentPreset: ImageProcessor.FilterPreset = .original
    @State private var rotation: Double = 0
    @State private var processedImage: NSImage?
    @Environment(\.dismiss) private var dismiss
    
    private let imageProcessor = ImageProcessor()
    
    var body: some View {
        VStack(spacing: 0) {
            // Image display
            imageSection
            
            Divider()
            
            // Controls
            controlSection
        }
        .frame(minWidth: 600, minHeight: 500)
        .task {
            loadImage()
        }
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        Group {
            if let image = processedImage {
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
    }
    
    // MARK: - Controls Section
    
    private var controlSection: some View {
        HStack(spacing: 24) {
            // Rotation controls
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        rotation -= 90
                    }
                } label: {
                    Label("Rotate Left", systemImage: "rotate.left")
                }
                .buttonStyle(.borderless)
                .help("Rotate left 90°")
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        rotation += 90
                    }
                } label: {
                    Label("Rotate Right", systemImage: "rotate.right")
                }
                .buttonStyle(.borderless)
                .help("Rotate right 90°")
            }
            
            Divider()
                .frame(height: 20)
            
            // Filter presets
            HStack(spacing: 12) {
                Text("Filter:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Filter", selection: $currentPreset) {
                    ForEach(ImageProcessor.FilterPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                .labelsHidden()
                .onChange(of: currentPreset) { _, newValue in
                    applyPreset(newValue)
                }
            }
            
            Spacer()
            
            // Done button
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }
    
    // MARK: - Actions
    
    private func loadImage() {
        processedImage = page.image
    }
    
    private func applyPreset(_ preset: ImageProcessor.FilterPreset) {
        guard let originalImage = page.image,
              let tiffData = originalImage.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return }
        
        let processed = imageProcessor.applyPreset(preset, to: ciImage)
        processedImage = imageProcessor.nsImage(from: processed)
    }
}

#Preview {
    EditorView(page: Page(imagePath: "test.jpg"))
}
