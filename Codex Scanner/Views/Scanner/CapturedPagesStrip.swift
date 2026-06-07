//
//  CapturedPagesStrip.swift
//  Codex Scanner
//

import SwiftUI

struct CapturedPagesStrip: View {
    let pages: [CapturedPage]
    let onDelete: (CapturedPage) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    VStack(spacing: Theme.Spacing.xs) {
                        thumbnail(page)
                        Text("\(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            onDelete(page)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(height: 110)
        .background(.bar)
    }

    @ViewBuilder
    private func thumbnail(_ page: CapturedPage) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        if let thumb = page.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 80)
                .clipShape(shape)
                .overlay(shape.stroke(Color.appBorder, lineWidth: 0.5))
        } else {
            shape
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 60, height: 80)
        }
    }
}

#Preview {
    CapturedPagesStrip(pages: [], onDelete: { _ in })
        .frame(width: 500)
}
