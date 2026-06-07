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
