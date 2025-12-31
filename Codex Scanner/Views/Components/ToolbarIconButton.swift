//
//  ToolbarIconButton.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/30/25.
//

import SwiftUI

/// A reusable toolbar icon button with native macOS styling
/// Provides subtle hover states and accent color for active state
struct ToolbarIconButton: View {
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    init(
        icon: String,
        isActive: Bool = false,
        activeColor: Color = .accentColor,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.isActive = isActive
        self.activeColor = activeColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: 32, height: 32)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
    
    private var foregroundColor: Color {
        if isActive {
            return activeColor
        }
        return isHovered ? .primary : .secondary
    }
    
    private var backgroundColor: Color {
        if isActive {
            return activeColor.opacity(0.12)
        }
        return isHovered ? Color.primary.opacity(0.06) : .clear
    }
}

#Preview {
    HStack(spacing: 8) {
        ToolbarIconButton(icon: "rectangle.stack", isActive: false) {}
        ToolbarIconButton(icon: "plus", isActive: false) {}
        ToolbarIconButton(icon: "doc.viewfinder", isActive: true) {}
        ToolbarIconButton(icon: "eyeglasses", isActive: false) {}
        ToolbarIconButton(icon: "arrow.uturn.backward", isActive: false) {}
    }
    .padding(20)
}
