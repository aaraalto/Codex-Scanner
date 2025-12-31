//
//  ScannedPagesStrip.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Horizontal scrolling strip of scanned page thumbnails
/// Notion-meets-Apple design: clean, minimal, content-focused
struct ScannedPagesStrip: View {
    let pages: [CapturedPage]
    let coverImage: NSImage?
    let onDeletePage: (CapturedPage) -> Void
    let onTapPage: ((CapturedPage) -> Void)?
    
    // Track deletions for ripple effect
    @State private var deletedIndex: Int? = nil
    @State private var ripplePhase: Double = 0
    @State private var previousPageCount: Int = 0
    
    // Design constants - adjusted for larger higher-res thumbnails
    private let stripHeight: CGFloat = 240
    private let horizontalPadding: CGFloat = 24
    private let thumbnailSpacing: CGFloat = 16
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
            // Subtle top border
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
            
            VStack(spacing: 0) {
                // Minimal header
                HStack(alignment: .center) {
                    Text(pageCountText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
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
                        .padding(.bottom, 12)
                        .onChange(of: pages.count) { oldCount, newCount in
                            if newCount > oldCount, let lastPage = pages.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastPage.id, anchor: .trailing)
                                }
                            }
                            previousPageCount = newCount
                        }
                    }
                }
            }
            .frame(height: stripHeight)
            .background(Color(nsColor: .windowBackgroundColor))
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

/// Cover image thumbnail - clean minimal style
private struct CoverThumbnail: View {
    let image: NSImage
    
    private let thumbnailWidth: CGFloat = 80
    private let thumbnailHeight: CGFloat = 104
    private let cornerRadius: CGFloat = 6
    
    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            Text("Cover")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
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
