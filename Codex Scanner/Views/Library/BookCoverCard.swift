//
//  BookCoverCard.swift
//  Codex Scanner
//

import SwiftUI

struct BookCoverCard: View {
    let book: Book
    var onRename: () -> Void
    var onExport: () -> Void
    var onDelete: () -> Void

    var body: some View {
        NavigationLink(value: Route.book(book)) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                cover
                Text(book.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("\(book.pageCount) page\(book.pageCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onRename() } label: { Label("Rename…", systemImage: "pencil") }
            Button { onExport() } label: { Label("Export as PDF…", systemImage: "arrow.up.doc") }
                .disabled(book.pages.isEmpty)
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
        return ZStack {
            shape.fill(Color.appContentBackground)
            if let image = book.coverPage?.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 150)
        .clipShape(shape)
        .overlay(shape.stroke(Color.appBorder, lineWidth: 0.5))
    }
}

#Preview {
    NavigationStack {
        BookCoverCard(book: Book(title: "Sample Book"), onRename: {}, onExport: {}, onDelete: {})
            .frame(width: 170)
            .padding()
    }
}
