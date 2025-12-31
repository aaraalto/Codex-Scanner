//
//  ScanThumbnail.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Individual scanned page thumbnail with liquid glass styling
/// Shows page image, page numbers, and hover state with delete button
/// Features a particle dissolution effect when deleted
/// Supports macOS Dock-style pull-up to delete gesture
struct ScanThumbnail: View {
    let image: NSImage?
    let pageNumbers: String
    let onDelete: () -> Void
    let onTap: (() -> Void)?
    
    @State private var isHovered = false
    @State private var isDissolving = false
    @State private var dissolveProgress: Double = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showDeleteHint = false
    
    // Design constants
    private let thumbnailWidth: CGFloat = 100
    private let thumbnailHeight: CGFloat = 132
    private let cornerRadius: CGFloat = 12
    private let dissolveDuration: Double = 0.5
    private let deleteThreshold: CGFloat = -80 // How far up to drag to delete
    
    init(
        image: NSImage?,
        pageNumbers: String,
        onDelete: @escaping () -> Void,
        onTap: (() -> Void)? = nil
    ) {
        self.image = image
        self.pageNumbers = pageNumbers
        self.onDelete = onDelete
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Thumbnail image container with dissolve effect
            thumbnailContent
                .layerEffect(
                    ShaderLibrary.particleDissolve(
                        .float(dissolveProgress),
                        .float2(thumbnailWidth, thumbnailHeight)
                    ),
                    maxSampleOffset: .zero, // Particles contained within bounds
                    isEnabled: isDissolving
                )
                .offset(dragOffset)
                .opacity(deleteOpacity)
                .scaleEffect(deleteScale)
                .rotation3DEffect(
                    .degrees(Double(dragOffset.height) * 0.15),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.5
                )
                .gesture(deleteGesture)
            
            // Page numbers label - also fade out during dissolution
            Text(pageNumbers)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .opacity(isDissolving ? 1.0 - dissolveProgress : 1.0)
        }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            guard !isDissolving && !isDragging else { return }
            isHovered = hovering
        }
        .onTapGesture {
            guard !isDissolving && !isDragging else { return }
            onTap?()
        }
        .overlay(alignment: .top) {
            // Delete hint when dragging up
            if showDeleteHint {
                deleteHintBubble
                    .offset(y: -50)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    ))
            }
        }
    }
    
    // MARK: - Delete Hint Bubble
    
    private var deleteHintBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "trash.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Release to Delete")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.red)
                .shadow(color: .red.opacity(0.4), radius: 12, y: 4)
        )
    }
    
    // MARK: - Computed Properties for Drag
    
    private var deleteOpacity: Double {
        guard isDragging else { return 1.0 }
        let progress = min(1.0, abs(dragOffset.height) / abs(deleteThreshold))
        return 1.0 - (progress * 0.3)
    }
    
    private var deleteScale: CGFloat {
        guard isDragging else { return 1.0 }
        let progress = min(1.0, abs(dragOffset.height) / abs(deleteThreshold))
        return 1.0 - (progress * 0.15)
    }
    
    // MARK: - Delete Gesture (Dock-style pull up)
    
    private var deleteGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isDissolving else { return }
                isDragging = true
                isHovered = false
                
                // Only allow upward drag for delete
                let translation = value.translation
                if translation.height < 0 {
                    // Rubber band effect - gets harder to drag as you go further
                    let resistance: CGFloat = 0.6
                    dragOffset = CGSize(
                        width: translation.width * 0.3,
                        height: translation.height * resistance
                    )
                    
                    // Show delete hint when past threshold
                    let pastThreshold = translation.height < deleteThreshold
                    if pastThreshold != showDeleteHint {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showDeleteHint = pastThreshold
                        }
                    }
                } else {
                    dragOffset = CGSize(width: translation.width * 0.1, height: 0)
                }
            }
            .onEnded { value in
                isDragging = false
                
                // If dragged past threshold, delete with poof effect
                if value.translation.height < deleteThreshold {
                    performPoofDelete()
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        dragOffset = .zero
                        showDeleteHint = false
                    }
                }
            }
    }
    
    // MARK: - Thumbnail Content
    
    private var thumbnailContent: some View {
        ZStack {
            // Image or placeholder
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .overlay {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundStyle(.quaternary)
                    }
            }
            
            // Hover overlay with glass delete button (no scale change)
            if isHovered && !isDissolving && !isDragging {
                Rectangle()
                    .fill(.black.opacity(0.45))
                    .transition(.opacity)
                
                Button(action: deleteWithEffect) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .fill(Color.red.opacity(0.75))
                                )
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.red.opacity(0.5), radius: 10)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .opacity(isDissolving ? 1.0 - dissolveProgress : 1.0)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
    
    // MARK: - Deletion Effects
    
    /// Poof effect for drag-to-delete (like macOS Dock)
    private func performPoofDelete() {
        // Play poof sound
        if let sound = NSSound(named: "Funk") {
            sound.play()
        }
        
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: 0, height: -30)
            showDeleteHint = false
        }
        
        // Trigger dissolve
        isDissolving = true
        withAnimation(.easeOut(duration: dissolveDuration * 0.6)) {
            dissolveProgress = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dissolveDuration * 0.6) {
            onDelete()
        }
    }
    
    /// Triggers the particle dissolution effect before calling onDelete
    private func deleteWithEffect() {
        guard !isDissolving else { return }
        
        isDissolving = true
        isHovered = false
        
        // Animate the dissolution progress
        withAnimation(.easeOut(duration: dissolveDuration)) {
            dissolveProgress = 1.0
        }
        
        // Call the actual delete after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + dissolveDuration) {
            onDelete()
        }
    }
}

/// Empty placeholder slot with glass styling
struct EmptyScanSlot: View {
    private let slotWidth: CGFloat = 100
    private let slotHeight: CGFloat = 132
    private let cornerRadius: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.2))
                .frame(width: slotWidth, height: slotHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [8, 5])
                        )
                        .foregroundStyle(Color.white.opacity(0.12))
                )
            
            // Spacer for alignment
            Text(" ")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.clear)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ScanThumbnail(
            image: nil,
            pageNumbers: "1—2",
            onDelete: { print("Delete") }
        )
        
        EmptyScanSlot()
        EmptyScanSlot()
    }
    .padding(40)
    .background(Color(nsColor: .windowBackgroundColor))
}
