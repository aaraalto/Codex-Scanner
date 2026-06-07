//
//  PageGridCell.swift
//  Codex Scanner
//

import SwiftUI

struct PageGridCell: View {
    let page: Page
    let pageNumber: Int

    var body: some View {
        NavigationLink(value: Route.page(page)) {
            VStack(spacing: Theme.Spacing.xs) {
                thumbnail
                Text("Page \(pageNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        return ZStack {
            shape.fill(Color.appContentBackground)
            if let image = page.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .frame(height: 160)
        .clipShape(shape)
        .overlay(shape.stroke(Color.appBorder, lineWidth: 0.5))
    }
}

#Preview {
    NavigationStack {
        PageGridCell(page: Page(imagePath: "x.jpg"), pageNumber: 1)
            .frame(width: 170)
            .padding()
    }
}
