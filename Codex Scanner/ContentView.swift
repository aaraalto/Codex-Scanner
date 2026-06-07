//
//  ContentView.swift
//  Codex Scanner
//
//  The single-window navigation shell.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            LibraryHomeView(onNewScan: pushScan)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .book(let book): BookDetailView(book: book)
                    case .page(let page): PageEditorScreen(page: page)
                    case .scan: ScannerScreen(onFinished: { path.removeAll() })
                    }
                }
        }
        .frame(minWidth: 900, minHeight: 650)
        .focusedSceneValue(\.navigationPath, $path)
    }

    private func pushScan() {
        if path.last != .scan { path.append(.scan) }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Page.self], inMemory: true)
}
