//
//  ScanningSettingsView.swift
//  Codex Scanner
//
//  Adjustable scanning settings panel
//

import SwiftUI

/// Settings panel for adjusting scanning behavior
struct ScanningSettingsView: View {
    @ObservedObject var settings = ScanningSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Presets
                    presetsSection
                    
                    Divider()
                    
                    // Capture Settings
                    captureSection
                    
                    Divider()
                    
                    // Processing Settings
                    processingSection
                    
                    Divider()
                    
                    // Performance Settings
                    performanceSection
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 420, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scanning Settings")
                    .font(.system(.headline, design: .rounded))
                Text("Adjust capture behavior and quality")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Presets", systemImage: "sparkles")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(ScanningSettings.ScanningPreset.allCases) { preset in
                    PresetButton(
                        title: preset.rawValue,
                        description: preset.description,
                        isSelected: false  // Could track current preset
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            settings.applyPreset(preset)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Capture Section
    
    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Capture", systemImage: "camera.viewfinder")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            
            // Stability Threshold
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Stability Threshold")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                    Text("\(settings.stabilityThreshold) frames")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(settings.stabilityThreshold) },
                        set: { settings.stabilityThreshold = Int($0) }
                    ),
                    in: 5...30,
                    step: 1
                )
                
                Text("Lower = faster capture, Higher = steadier result")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            // Movement Tolerance
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Movement Tolerance")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                    Text(String(format: "%.0f%%", settings.movementTolerance * 100))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Slider(
                    value: $settings.movementTolerance,
                    in: 0.01...0.1
                )
                
                Text("Lower = stricter, requires less movement")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            // Detection Confidence
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Detection Confidence")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                    Text(String(format: "%.0f%%", settings.detectionConfidenceThreshold * 100))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(settings.detectionConfidenceThreshold) },
                        set: { settings.detectionConfidenceThreshold = Float($0) }
                    ),
                    in: 0.3...0.95
                )
                
                Text("Minimum confidence to detect a document")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - Processing Section
    
    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Image Processing", systemImage: "wand.and.stars")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            
            // Toggle options
            Toggle(isOn: $settings.enhancedSharpening) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enhanced Sharpening")
                        .font(.system(.subheadline, design: .rounded))
                    Text("Better text clarity, slight performance cost")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .toggleStyle(.switch)
            
            Toggle(isOn: $settings.shadowRemoval) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shadow Removal")
                        .font(.system(.subheadline, design: .rounded))
                    Text("Reduce shadows from page edges")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .toggleStyle(.switch)
            
            // Compression Quality
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Image Quality")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                    Text(String(format: "%.0f%%", settings.imageCompressionQuality * 100))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Slider(
                    value: $settings.imageCompressionQuality,
                    in: 0.7...1.0
                )
                
                Text("Higher = better quality, larger files")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Performance", systemImage: "gauge.with.dots.needle.67percent")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            
            // Frame Processing Interval
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Frame Rate")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                    Text("\(1000 / settings.frameProcessingInterval) fps")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(settings.frameProcessingInterval) },
                        set: { settings.frameProcessingInterval = Int($0) }
                    ),
                    in: 50...200,
                    step: 10
                )
                
                Text("Higher = smoother preview, more CPU usage")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            // Thumbnail Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Thumbnail Size")
                    .font(.system(.subheadline, design: .rounded))
                
                Picker("", selection: $settings.thumbnailSize) {
                    ForEach(ScanningSettings.ThumbnailSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Max Pages in Memory
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Pages in Memory")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                    Text("\(settings.maxPagesInMemory)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(settings.maxPagesInMemory) },
                        set: { settings.maxPagesInMemory = Int($0) }
                    ),
                    in: 5...50,
                    step: 5
                )
                
                Text("Older pages cached to disk to save RAM")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Button("Reset to Defaults") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    settings.resetToDefaults()
                }
            }
            .foregroundStyle(.secondary)
            
            Spacer()
            
            Button("Done") {
                settings.saveToUserDefaults()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Text(description)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScanningSettingsView()
}
