//
//  ScannedPagesStrip.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Horizontal scrolling strip of scanned page thumbnails with native macOS styling
/// Displays at the bottom of the scanner view with vibrancy effects
struct ScannedPagesStrip: View {
    let pages: [CapturedPage]
    let coverImage: NSImage?
    let onDeletePage: (CapturedPage) -> Void
    let onTapPage: ((CapturedPage) -> Void)?
    
    // Design constants
    private let stripHeight: CGFloat = 220
    private let horizontalPadding: CGFloat = 20
    private let thumbnailSpacing: CGFloat = 12
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
            Divider()
            
            VStack(spacing: 0) {
                // Header with page count
                HStack {
                    Text(pageCountText)
                        .font(.system(.subheadline, design: .default, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                // Horizontal scroll of thumbnails
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        HStack(alignment: .top, spacing: thumbnailSpacing) {
                            // Cover scan thumbnail (if available)
                            if let coverImage = coverImage {
                                CoverThumbnail(image: coverImage)
                                    .id("cover")
                            }
                            
                            // Scanned pages
                            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                                ScanThumbnail(
                                    image: page.thumbnail ?? page.displayImage,
                                    pageNumbers: formatPageNumbers(index: index),
                                    onDelete: { onDeletePage(page) },
                                    onTap: { onTapPage?(page) }
                                )
                                .id(page.id)
                            }
                            
                            // Empty placeholder slots
                            if pages.count < emptySlotCount {
                                ForEach(0..<(emptySlotCount - pages.count), id: \.self) { _ in
                                    EmptyScanSlot()
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .onChange(of: pages.count) { _, _ in
                            // Auto-scroll to newest page
                            if let lastPage = pages.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastPage.id, anchor: .trailing)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: stripHeight)
            .background(.bar)
        }
    }
    
    private var pageCountText: String {
        let count = pages.count
        if count == 0 {
            return "No Pages Scanned"
        } else if count == 1 {
            return "1 Page"
        } else {
            return "\(count) Pages"
        }
    }
    
    private func formatPageNumbers(index: Int) -> String {
        // Format as "1—2" for book spreads (pairs of pages)
        let startPage = (index * 2) + 1
        let endPage = startPage + 1
        return "\(startPage)—\(endPage)"
    }
}

/// Cover image thumbnail with special styling
private struct CoverThumbnail: View {
    let image: NSImage
    
    private let thumbnailWidth: CGFloat = 80
    private let thumbnailHeight: CGFloat = 140
    private let cornerRadius: CGFloat = 6
    
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            
            Text("Cover")
                .font(.system(.caption2, design: .rounded, weight: .medium))
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
}
