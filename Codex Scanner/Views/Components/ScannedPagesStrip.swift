//
//  ScannedPagesStrip.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Horizontal scrolling strip of scanned page thumbnails with macOS Tahoe styling
/// Displays at the bottom of the scanner view with refined visual design
/// Features ripple animation when pages are deleted
struct ScannedPagesStrip: View {
    let pages: [CapturedPage]
    let coverImage: NSImage?
    let onDeletePage: (CapturedPage) -> Void
    let onTapPage: ((CapturedPage) -> Void)?
    
    // Track deletions for ripple effect
    @State private var deletedIndex: Int? = nil
    @State private var ripplePhase: Double = 0
    @State private var previousPageCount: Int = 0
    
    // Design constants
    private let stripHeight: CGFloat = 230
    private let horizontalPadding: CGFloat = 32
    private let thumbnailSpacing: CGFloat = 20
    private let emptySlotCount: Int = 3
    
    init(
        pages: [CapturedPage],
        coverImage: NSImage? = nil,
        onDeletePage: @escaping (CapturedPage) -> Void,
        onTapPage: ((CapturedPage) -> Void)? = nil
    ) {
        self.pages = pages
        self.coverImage = coverImage
        self.onDeletePage = onDeletePage
        self.onTapPage = onTapPage
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Refined glass divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.03)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            VStack(spacing: 0) {
                // Minimal header with page count
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: pages.isEmpty ? "doc.text" : "doc.text.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(pages.isEmpty ? .tertiary : .secondary)
                        
                        Text(pageCountText)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !pages.isEmpty {
                        Text("Drag up to remove")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Horizontal scroll of thumbnails
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        HStack(alignment: .top, spacing: thumbnailSpacing) {
                            // Cover scan thumbnail (if available)
                            if let coverImage = coverImage {
                                CoverThumbnail(image: coverImage)
                                    .id("cover")
                            }
                            
                            // Scanned pages with ripple effect
                            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                                ScanThumbnail(
                                    image: page.thumbnail ?? page.displayImage,
                                    pageNumbers: formatPageNumbers(index: index),
                                    onDelete: { handleDelete(page: page, at: index) },
                                    onTap: { onTapPage?(page) }
                                )
                                .id(page.id)
                                .modifier(RippleModifier(
                                    index: index,
                                    deletedIndex: deletedIndex,
                                    ripplePhase: ripplePhase,
                                    totalCount: pages.count
                                ))
                            }
                            
                            // Empty placeholder slots
                            if pages.count < emptySlotCount {
                                ForEach(0..<(emptySlotCount - pages.count), id: \.self) { slotIndex in
                                    EmptyScanSlot()
                                        .modifier(RippleModifier(
                                            index: pages.count + slotIndex,
                                            deletedIndex: deletedIndex,
                                            ripplePhase: ripplePhase,
                                            totalCount: pages.count + (emptySlotCount - pages.count)
                                        ))
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 16)
                        .onChange(of: pages.count) { oldCount, newCount in
                            // Auto-scroll to newest page when adding
                            if newCount > oldCount, let lastPage = pages.last {
                                withAnimation(.easeOut(duration: 0.4)) {
                                    proxy.scrollTo(lastPage.id, anchor: .trailing)
                                }
                            }
                            previousPageCount = newCount
                        }
                    }
                }
            }
            .frame(height: stripHeight)
            .background(.regularMaterial)
        }
    }
    
    // MARK: - Delete Handler with Ripple
    
    private func handleDelete(page: CapturedPage, at index: Int) {
        // Set the deleted index to trigger ripple
        deletedIndex = index
        ripplePhase = 0
        
        // Animate the ripple
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            ripplePhase = 1.0
        }
        
        // Call the actual delete
        onDeletePage(page)
        
        // Reset ripple state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            deletedIndex = nil
            ripplePhase = 0
        }
    }
    
    private var pageCountText: String {
        let count = pages.count
        if count == 0 {
            return "No Pages"
        } else if count == 1 {
            return "1 Page"
        } else {
            return "\(count) Pages"
        }
    }
    
    private func formatPageNumbers(index: Int) -> String {
        let startPage = (index * 2) + 1
        let endPage = startPage + 1
        return "\(startPage)–\(endPage)"
    }
}

// MARK: - Ripple Animation Modifier

/// Applies a wave/ripple effect to thumbnails when a sibling is deleted
private struct RippleModifier: ViewModifier {
    let index: Int
    let deletedIndex: Int?
    let ripplePhase: Double
    let totalCount: Int
    
    func body(content: Content) -> some View {
        content
            .offset(y: rippleOffset)
            .scaleEffect(rippleScale)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.5)
                    .delay(rippleDelay),
                value: ripplePhase
            )
    }
    
    // Calculate ripple offset based on distance from deleted item
    private var rippleOffset: CGFloat {
        guard let deleted = deletedIndex, ripplePhase > 0 else { return 0 }
        
        // Only affect items after the deleted one (they're moving left)
        if index <= deleted { return 0 }
        
        // Distance from deleted item
        let distance = index - deleted
        
        // Ripple diminishes with distance
        let amplitude: CGFloat = 8.0
        let decay = exp(-Double(distance) * 0.5)
        
        // Wave motion - bounces up then settles
        let wave = sin(ripplePhase * .pi) * (1.0 - ripplePhase * 0.5)
        
        return -CGFloat(wave * decay) * amplitude
    }
    
    // Subtle scale pulse during ripple
    private var rippleScale: CGFloat {
        guard let deleted = deletedIndex, ripplePhase > 0 else { return 1.0 }
        
        if index <= deleted { return 1.0 }
        
        let distance = index - deleted
        let decay = exp(-Double(distance) * 0.6)
        
        // Quick scale pulse
        let pulse = sin(ripplePhase * .pi * 2) * 0.03 * decay
        
        return 1.0 + CGFloat(pulse)
    }
    
    // Stagger delay for wave propagation
    private var rippleDelay: Double {
        guard let deleted = deletedIndex else { return 0 }
        
        if index <= deleted { return 0 }
        
        let distance = index - deleted
        return Double(distance) * 0.03 // 30ms between each item
    }
}

/// Cover image thumbnail with glass styling
private struct CoverThumbnail: View {
    let image: NSImage
    
    private let thumbnailWidth: CGFloat = 90
    private let thumbnailHeight: CGFloat = 120
    private let cornerRadius: CGFloat = 10
    
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            
            Text("Cover")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ScannedPagesStrip(
            pages: [],
            coverImage: nil,
            onDeletePage: { _ in }
        )
    }
    .frame(height: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}
