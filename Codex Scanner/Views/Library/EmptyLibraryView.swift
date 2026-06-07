//
//  EmptyLibraryView.swift
//  Codex Scanner
//

import SwiftUI

struct EmptyLibraryView: View {
    var onNewScan: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Scan your first book")
                    .font(.title2.weight(.semibold))
                Text("Prop your iPhone over a book and Codex Scanner captures each page automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                stepCard(number: 1, title: "Prop your iPhone", systemImage: "iphone")
                stepCard(number: 2, title: "Capture pages", systemImage: "camera.viewfinder")
                stepCard(number: 3, title: "Export PDF", systemImage: "arrow.up.doc")
            }

            Button(action: onNewScan) {
                Label("New Scan", systemImage: "plus")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
        .padding(Theme.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stepCard(number: Int, title: String, systemImage: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
        return VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(.tint)
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .frame(width: 120, height: 110)
        .padding(Theme.Spacing.md)
        .background(Color.appSurface, in: shape)
        .overlay(shape.stroke(Color.appBorder, lineWidth: 0.5))
    }
}

#Preview {
    EmptyLibraryView(onNewScan: {})
        .frame(width: 700, height: 520)
}
