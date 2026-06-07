//
//  Route.swift
//  Codex Scanner
//
//  Typed navigation routes for the single-window NavigationStack.
//

import SwiftUI

/// One destination on the navigation stack. The library is the root, so it is
/// not represented here — only what you can push onto it.
enum Route: Hashable {
    case book(Book)   // page grid for a book
    case page(Page)   // page editor
    case scan         // the scanner
}

/// Focused value carrying a binding to the navigation path, so menu commands
/// (e.g. File ▸ New Scan / ⌘N) can push routes without owning the path.
struct NavigationPathKey: FocusedValueKey {
    typealias Value = Binding<[Route]>
}

extension FocusedValues {
    var navigationPath: Binding<[Route]>? {
        get { self[NavigationPathKey.self] }
        set { self[NavigationPathKey.self] = newValue }
    }
}
