//
//  PageThumbnail.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Thumbnail view for displaying a page in the library grid with native macOS styling
struct PageThumbnail: View {
    let page: Page
    let isSelected: Bool
    
    @State private var isHovered = false
    
    // Silky smooth hover animation
    private let hoverSpring = Animation.spring(response: 0.35, dampingFraction: 0.72, blendDuration: 0)
    
    var body: some View {
        VStack(spacing: 8) {
            if let image = page.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isHovered || isSelected ? Color.white.opacity(0.2) : Color.clear,
                                lineWidth: 1
                            )
                    )
                    // Dynamic shadow elevation on hover
                    .shadow(
                        color: .black.opacity(isHovered ? 0.2 : 0.08),
                        radius: isHovered ? 14 : 4,
                        y: isHovered ? 7 : 2
                    )
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: 180)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.quaternary)
                    }
            }
            
            Text("Page \(page.order + 1)")
                .font(.caption)
                .foregroundStyle(isHovered ? .primary : .secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        // Silky smooth hover transformations
        .scaleEffect(isHovered && !isSelected ? 1.025 : 1.0)
        .offset(y: isHovered && !isSelected ? -4 : 0)
        .animation(hoverSpring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
    }
}
