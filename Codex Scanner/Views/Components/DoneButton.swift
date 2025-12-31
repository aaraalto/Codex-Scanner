//
//  DoneButton.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Done button using native macOS button styling
/// Presents a prominent action to complete the scanning session
struct DoneButton: View {
    let action: () -> Void
    let isEnabled: Bool
    
    init(isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Label("Done", systemImage: "checkmark")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        DoneButton(isEnabled: true) {
            print("Done tapped")
        }
        DoneButton(isEnabled: false) {
            print("Done tapped")
        }
    }
    .padding(20)
}
