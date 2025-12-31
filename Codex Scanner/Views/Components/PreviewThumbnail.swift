//
//  PreviewThumbnail.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Thumbnail view for displaying a captured page in the preview sidebar
/// Uses native macOS styling with subtle selection states
struct PreviewThumbnail: View {
    let page: CapturedPage
    let pageNumber: Int
    let isSelected: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 6) {
            if let thumbnail = page.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(isSelected ? 0.15 : 0.08), radius: isSelected ? 6 : 3, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: 100)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
            
            Text("\(pageNumber)")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
    }
}
