//
//  BookTitlePill.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Displays the current book title with macOS Tahoe styling
/// Clickable to edit the title - bigger, more prominent design
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
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if onTap != nil {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.regularMaterial.opacity(isHovered ? 1 : 0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.25 : 0.15),
                                Color.white.opacity(isHovered ? 0.1 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
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
    VStack(spacing: 24) {
        BookTitlePill(title: "The Great Gatsby")
        BookTitlePill(title: "Untitled Book") {
            print("Tapped")
        }
    }
    .padding(40)
    .background(Color(nsColor: .windowBackgroundColor))
}
