//
//  AppCommands.swift
//  Codex Scanner
//
//  Menu-bar commands for the single-window shell.
//

import SwiftUI

/// File ▸ New Scan (⌘N). Pushes the scanner onto the focused window's nav path.
struct ScanCommands: Commands {
    @FocusedValue(\.navigationPath) private var path

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Scan") {
                if path?.wrappedValue.last != .scan {
                    path?.wrappedValue.append(.scan)
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(path == nil)
        }
    }
}
