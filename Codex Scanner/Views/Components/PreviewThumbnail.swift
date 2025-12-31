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
    
    // Silky smooth hover animation
    private let hoverSpring = Animation.spring(response: 0.35, dampingFraction: 0.72, blendDuration: 0)
    
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
                                isHovered || isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.15),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    // Dynamic shadow elevation
                    .shadow(
                        color: .black.opacity(isHovered ? 0.22 : (isSelected ? 0.2 : 0.1)),
                        radius: isHovered ? 12 : (isSelected ? 8 : 4),
                        y: isHovered ? 6 : 3
                    )
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
        // Silky smooth hover transformations
        .scaleEffect(isHovered && !isSelected ? 1.03 : 1.0)
        .offset(y: isHovered && !isSelected ? -3 : 0)
        .animation(hoverSpring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
    }
}
