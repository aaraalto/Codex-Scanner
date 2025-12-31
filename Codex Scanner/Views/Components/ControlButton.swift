//
//  ControlButton.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// A reusable control button with native macOS Tahoe styling
/// Features icon, label, and active state indication
/// Bigger, more prominent design for better usability
struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    private let buttonSize: CGFloat = 64
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isActive ? color : (isHovered ? .primary : .secondary))
            .frame(width: buttonSize, height: buttonSize)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? color.opacity(0.15) : (isHovered ? Color.primary.opacity(0.07) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? color.opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    HStack(spacing: 14) {
        ControlButton(icon: "play.fill", label: "Play", isActive: true, color: .green) {}
        ControlButton(icon: "pause.fill", label: "Pause", isActive: false, color: .orange) {}
    }
    .padding(24)
}
