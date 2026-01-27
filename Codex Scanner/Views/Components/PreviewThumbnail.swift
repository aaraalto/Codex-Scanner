//
//  PreviewThumbnail.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Thumbnail view for displaying a captured page in the preview sidebar
/// Uses native macOS Tahoe styling with refined selection states
struct PreviewThumbnail: View {
    let page: CapturedPage
    let pageNumber: Int
    let isSelected: Bool
    
    @State private var isHovered = false
    
    private let thumbnailHeight: CGFloat = 110
    private let cornerRadius: CGFloat = 10
    
    // Snappy, simple animation for border only
    private let hoverAnimation = Animation.easeOut(duration: 0.1)
    
    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail = page.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: thumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                isHovered || isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.1),
                                lineWidth: isHovered || isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: thumbnailHeight)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
            
            Text("\(pageNumber)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? .primary : (isHovered ? .secondary : .tertiary))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        // No scale or lift - just border interaction
        .animation(hoverAnimation, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
    }
}
