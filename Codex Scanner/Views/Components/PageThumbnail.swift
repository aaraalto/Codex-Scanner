//
//  PageThumbnail.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Thumbnail view for displaying a page in the library grid
struct PageThumbnail: View {
    let page: Page
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            if let image = page.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 180)
                    .cornerRadius(8)
                    .shadow(radius: isSelected ? 4 : 2)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 180)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
            }
            
            Text("Page \(page.order + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
