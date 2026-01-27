//
//  ScanThumbnail.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Individual scanned page thumbnail - clean minimal style
/// Shows page image, page numbers, and hover state with delete
/// Features particle dissolution effect when deleted
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
    
    // MARK: - Design Constants
    
    // Thumbnail dimensions
    private let thumbnailWidth: CGFloat = 80
    private let thumbnailHeight: CGFloat = 104
    private let cornerRadius: CGFloat = 6
    
    // Overlay sizing
    private let overlayPadding: CGFloat = 2  // Makes overlay slightly larger than thumbnail
    private let borderWidthNormal: CGFloat = 1
    private let borderWidthHover: CGFloat = 2
    private let shadowRadius: CGFloat = 4
    private let shadowOffsetY: CGFloat = 2
    private let shadowOpacity: Double = 0.1
    
    // Delete hint bubble sizing
    private let deleteHintHorizontalPadding: CGFloat = 8
    private let deleteHintVerticalPadding: CGFloat = 4
    private let deleteHintOffsetY: CGFloat = -40
    private let deleteHintScale: CGFloat = 0.85
    
    // Delete button sizing
    private let deleteButtonScale: CGFloat = 0.9
    
    // Animation & interaction
    private let dissolveDuration: Double = 0.6
    private let deleteThreshold: CGFloat = -60
    private let hoverAnimation = Animation.easeOut(duration: 0.1)
    
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
        VStack(spacing: 6) {
            // Thumbnail image container with dissolve effect
            thumbnailContent
                .layerEffect(
                    ShaderLibrary.particleDissolve(
                        .float(dissolveProgress),
                        .float2(thumbnailWidth, thumbnailHeight)
                    ),
                    maxSampleOffset: .zero,
                    isEnabled: isDissolving
                )
                .offset(dragOffset)
                .opacity(deleteOpacity)
                .scaleEffect(deleteScale)
                .rotation3DEffect(
                    .degrees(Double(dragOffset.height) * 0.12),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.5
                )
                .gesture(deleteGesture)
            
            // Page numbers label
            Text(pageNumbers)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .opacity(isDissolving ? 1.0 - dissolveProgress : 1.0)
        }
        // No scale or lift - just border interaction
        .onHover { hovering in
            guard !isDissolving && !isDragging else { return }
            isHovered = hovering
        }
        .onTapGesture {
            guard !isDissolving && !isDragging else { return }
            onTap?()
        }
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if showDeleteHint {
                deleteHintBubble
                    .offset(y: deleteHintOffsetY)
                    .transition(.asymmetric(
                        insertion: .scale(scale: deleteHintScale).combined(with: .opacity),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    ))
            }
        }
    }
    
    // MARK: - Delete Hint Bubble
    
    private var deleteHintBubble: some View {
        Label("Release to delete", systemImage: "trash")
            .font(.caption2)
            .padding(.horizontal, deleteHintHorizontalPadding)
            .padding(.vertical, deleteHintVerticalPadding)
            .background(.red, in: Capsule())
            .foregroundStyle(.white)
    }
    
    // MARK: - Overlay Computed Properties
    
    private var borderWidth: CGFloat {
        isHovered && !isDissolving && !isDragging ? borderWidthHover : borderWidthNormal
    }
    
    private var borderColor: Color {
        isHovered && !isDissolving && !isDragging 
            ? Color.white.opacity(0.6) 
            : Color.primary.opacity(0.08)
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
    
    // MARK: - Drag Gesture (free movement, snaps back - no reordering)
    
    private var deleteGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isDissolving else { return }
                isDragging = true
                isHovered = false
                
                let translation = value.translation
                
                // Allow free movement in all directions with slight resistance
                let resistance: CGFloat = 0.7
                dragOffset = CGSize(
                    width: translation.width * resistance,
                    height: translation.height * resistance
                )
                
                // Show delete hint only when dragged significantly upward
                if translation.height < deleteThreshold {
                    let pastThreshold = true
                    if pastThreshold != showDeleteHint {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showDeleteHint = true
                        }
                    }
                } else if showDeleteHint {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showDeleteHint = false
                    }
                }
            }
            .onEnded { value in
                isDragging = false
                
                // If dragged past upward threshold, delete with poof effect
                if value.translation.height < deleteThreshold {
                    performPoofDelete()
                } else {
                    // Snap back to original position (no reordering)
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
                    .fill(Color.primary.opacity(0.03))
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .overlay {
                        Image(systemName: "doc.text")
                            .font(.title3)
                            .foregroundStyle(.quaternary)
                    }
            }
            
            // Delete button (centered on thumbnail)
            if isHovered && !isDissolving && !isDragging {
                Button(action: deleteWithEffect) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.notionSecondary)
                .tint(.red)
                .controlSize(.small)
                .transition(.scale(scale: deleteButtonScale).combined(with: .opacity))
            }
        }
        .frame(width: thumbnailWidth, height: thumbnailHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background(alignment: .center) {
            // Hover overlay extends beyond thumbnail bounds
            if isHovered && !isDissolving && !isDragging {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(
                        width: thumbnailWidth + (overlayPadding * 2),
                        height: thumbnailHeight + (overlayPadding * 2)
                    )
                    .transition(.opacity)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderWidth)
                .opacity(isDissolving ? 1.0 - dissolveProgress : 1.0)
        )
        .animation(hoverAnimation, value: isHovered)
        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowOffsetY)
    }
    
    // MARK: - Deletion Effects
    
    /// Play a soft, pleasant delete sound
    private func playDeleteSound() {
        // Try different system sounds for a pleasant delete effect
        // "Blow" is a soft woosh, "Submarine" is gentle, "Glass" is crisp
        let soundNames = ["Blow", "Submarine", "Glass", "Pop"]
        for name in soundNames {
            if let sound = NSSound(named: name) {
                sound.volume = 0.6 // Softer volume
                sound.play()
                return
            }
        }
    }
    
    /// Poof effect for drag-to-delete (like macOS Dock)
    private func performPoofDelete() {
        playDeleteSound()
        
        // Gentle upward float before dissolving
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: 0, height: -20)
            showDeleteHint = false
        }
        
        // Trigger graceful dissolve
        isDissolving = true
        withAnimation(.easeInOut(duration: dissolveDuration)) {
            dissolveProgress = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dissolveDuration) {
            onDelete()
        }
    }
    
    /// Triggers the particle dissolution effect before calling onDelete
    private func deleteWithEffect() {
        guard !isDissolving else { return }
        
        playDeleteSound()
        
        isDissolving = true
        isHovered = false
        
        // Graceful ease-in-out animation for smooth dissolution
        withAnimation(.easeInOut(duration: dissolveDuration)) {
            dissolveProgress = 1.0
        }
        
        // Call the actual delete after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + dissolveDuration) {
            onDelete()
        }
    }
}

/// Empty placeholder slot - minimal dashed outline
struct EmptyScanSlot: View {
    private let slotWidth: CGFloat = 80
    private let slotHeight: CGFloat = 104
    private let cornerRadius: CGFloat = 6
    
    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
                .frame(width: slotWidth, height: slotHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                        .foregroundStyle(Color.primary.opacity(0.08))
                )
            
            // Spacer for alignment
            Text(" ")
                .font(.system(size: 10))
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
