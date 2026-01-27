//
//  ProcessingModeSelector.swift
//  Codex Scanner
//
//  UI component for selecting ML processing mode (Text/Photo/Mixed/Handwritten)
//

import SwiftUI

/// Compact selector for choosing the ML processing mode
struct ProcessingModeSelector: View {
    @Binding var selectedMode: ImageProcessor.ProcessingMode
    @Binding var autoDetect: Bool
    
    var body: some View {
        Menu {
            Toggle(isOn: $autoDetect) {
                Label("Auto-detect Content", systemImage: "wand.and.stars")
            }
            
            Divider()
            
            ForEach(ImageProcessor.ProcessingMode.allCases) { mode in
                Button {
                    autoDetect = false
                    selectedMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            Label(autoDetect ? "Auto" : selectedMode.rawValue, systemImage: autoDetect ? "wand.and.stars" : selectedMode.icon)
        }
        .menuStyle(.borderlessButton)
    }
}

/// Export quality selector for Apple Books
struct ExportQualitySelector: View {
    @Binding var quality: ImageProcessor.ExportQuality
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export Quality", systemImage: "square.and.arrow.up")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Picker("", selection: $quality) {
                ForEach(ImageProcessor.ExportQuality.allCases) { q in
                    HStack {
                        Text(q.rawValue)
                        Text("(\(Int(q.dpi)) DPI)")
                            .foregroundStyle(.secondary)
                    }
                    .tag(q)
                }
            }
            .pickerStyle(.segmented)
            .notionSegmentedPicker()
            
            // Quality description
            HStack {
                switch quality {
                case .standard:
                    Image(systemName: "doc")
                    Text("Smaller files, good for reading")
                case .high:
                    Image(systemName: "book")
                    Text("Recommended for Apple Books")
                case .maximum:
                    Image(systemName: "archivebox")
                    Text("Archival quality, largest files")
                }
            }
            .font(.system(.caption2, design: .rounded))
            .foregroundColor(.secondary)
        }
    }
}

#Preview("Compact Selector") {
    ProcessingModeSelector(
        selectedMode: .constant(.text),
        autoDetect: .constant(false)
    )
    .padding()
    .background(.black)
}

#Preview("Export Quality") {
    ExportQualitySelector(quality: .constant(.high))
        .padding()
        .frame(width: 400)
}
