//
//  BookTitlePill.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Displays the current book title with native macOS styling
/// Clickable to edit the title
struct BookTitlePill: View {
    let title: String
    let onTap: (() -> Void)?
    
    @State private var isHovered = false
    
    init(title: String, onTap: (() -> Void)? = nil) {
        self.title = title
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(title)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if onTap != nil {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .disabled(onTap == nil)
    }
}

#Preview {
    VStack(spacing: 20) {
        BookTitlePill(title: "The Great Gatsby")
        BookTitlePill(title: "Untitled Book") {
            print("Tapped")
        }
    }
    .padding(20)
}
