//
//  ScanThumbnail.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Individual scanned page thumbnail with native macOS styling
/// Shows page image, page numbers, and hover state with delete button
struct ScanThumbnail: View {
    let image: NSImage?
    let pageNumbers: String // e.g., "1—2" for a spread
    let onDelete: () -> Void
    let onTap: (() -> Void)?
    
    @State private var isHovered = false
    
    // Design constants
    private let thumbnailWidth: CGFloat = 100
    private let thumbnailHeight: CGFloat = 140
    private let cornerRadius: CGFloat = 8
    
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
        VStack(spacing: 8) {
            // Thumbnail image container
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
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .overlay {
                            Image(systemName: "doc.text")
                                .font(.title2)
                                .foregroundStyle(.quaternary)
                        }
                }
                
                // Hover overlay with delete button
                if isHovered {
                    Rectangle()
                        .fill(.black.opacity(0.4))
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.red)
                                    .shadow(color: .black.opacity(0.2), radius: 4)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 8 : 4, y: 2)
            
            // Page numbers label
            Text(pageNumbers)
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap?()
        }
    }
}

/// Empty placeholder slot for upcoming scans
struct EmptyScanSlot: View {
    private let slotWidth: CGFloat = 100
    private let slotHeight: CGFloat = 140
    private let cornerRadius: CGFloat = 8
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.02))
                .frame(width: slotWidth, height: slotHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                        .foregroundStyle(Color.primary.opacity(0.1))
                )
            
            // Spacer for alignment with labeled thumbnails
            Text(" ")
                .font(.system(.caption2, design: .monospaced))
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
    .padding(20)
}
