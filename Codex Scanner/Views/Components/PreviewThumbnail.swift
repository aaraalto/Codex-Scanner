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
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 8 : 4, y: 3)
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
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
    }
}
