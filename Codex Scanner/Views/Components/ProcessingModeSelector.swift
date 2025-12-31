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

/// Extended processing mode selector with visual cards
struct ProcessingModeCardSelector: View {
    @Binding var selectedMode: ImageProcessor.ProcessingMode
    @Binding var autoDetect: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with auto-detect toggle
            HStack {
                Label("Content Type", systemImage: "doc.viewfinder")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Toggle(isOn: $autoDetect) {
                    Text("Auto")
                        .font(.system(.caption, design: .rounded))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            
            // Mode cards
            HStack(spacing: 8) {
                ForEach(ImageProcessor.ProcessingMode.allCases) { mode in
                    ProcessingModeCard(
                        mode: mode,
                        isSelected: !autoDetect && selectedMode == mode,
                        isDisabled: autoDetect
                    ) {
                        autoDetect = false
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedMode = mode
                        }
                    }
                }
            }
            
            // Description
            if autoDetect {
                Text("ML will automatically detect the best processing for each page")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                Text(selectedMode.description)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Individual mode card
struct ProcessingModeCard: View {
    let mode: ImageProcessor.ProcessingMode
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.title3)
                Text(mode.rawValue)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : nil)
        .disabled(isDisabled)
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

#Preview("Card Selector") {
    ProcessingModeCardSelector(
        selectedMode: .constant(.mixed),
        autoDetect: .constant(true)
    )
    .padding()
    .frame(width: 400)
}

#Preview("Export Quality") {
    ExportQualitySelector(quality: .constant(.high))
        .padding()
        .frame(width: 400)
}
