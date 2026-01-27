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
    
    // Snappy, simple animation for border only
    private let hoverAnimation = Animation.easeOut(duration: 0.1)
    
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
                                isHovered || isSelected ? Color.white.opacity(0.6) : Color.clear,
                                lineWidth: isHovered || isSelected ? 2 : 0
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
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
        // No scale or lift - just border interaction
        .animation(hoverAnimation, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
    }
}
