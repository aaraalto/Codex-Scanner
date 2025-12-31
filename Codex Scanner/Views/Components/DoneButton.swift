//
//  DoneButton.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// Done button using native macOS Tahoe button styling
/// Presents a prominent action to complete the scanning session
/// Bigger, more prominent design for better usability
struct DoneButton: View {
    let action: () -> Void
    let isEnabled: Bool
    
    @State private var isHovered = false
    
    init(isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                Text("Done")
                    .font(.system(.body, design: .rounded, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isEnabled)
        .scaleEffect(isHovered && isEnabled ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        DoneButton(isEnabled: true) {
            print("Done tapped")
        }
        DoneButton(isEnabled: false) {
            print("Done tapped")
        }
    }
    .padding(24)
}
