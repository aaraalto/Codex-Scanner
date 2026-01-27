//
//  SolidToggleStyle.swift
//  Codex Scanner
//
//  Custom toggle style with solid, polished Notion-like design
//

import SwiftUI

/// Solid toggle style with refined Notion dark mode visual design
struct SolidToggleStyle: ToggleStyle {
    var size: ControlSize = .regular
    @State private var isHovered = false

    private var padding: CGFloat {
        switch size {
        case .mini: return 8
        case .small: return 10
        case .regular: return 12
        case .large: return 14
        case .extraLarge: return 16
        @unknown default: return 12
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .mini, .small: return 6
        case .regular: return 8
        case .large, .extraLarge: return 10
        @unknown default: return 8
        }
    }

    private var fontSize: CGFloat {
        switch size {
        case .mini: return 12
        case .small: return 13
        case .regular: return 14
        case .large: return 15
        case .extraLarge: return 16
        @unknown default: return 14
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .mini: return 14
        case .small: return 16
        case .regular: return 18
        case .large: return 20
        case .extraLarge: return 22
        @unknown default: return 18
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                configuration.label
                    .font(.system(size: iconSize, weight: configuration.isOn ? .semibold : .medium))
            }
            .foregroundStyle(configuration.isOn ? Color.notionTextPrimary : Color.notionTextSecondary)
            .padding(.horizontal, padding + 4)
            .padding(.vertical, padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        configuration.isOn
                            ? (isHovered ? Color.notionSurfaceHover : Color.notionSurface)
                            : (isHovered ? Color.notionSurfaceHover.opacity(0.4) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        configuration.isOn
                            ? Color.notionBorder
                            : Color.notionBorder.opacity(0.5),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: configuration.isOn
                    ? Color.black.opacity(0.2)
                    : Color.clear,
                radius: configuration.isOn ? 2 : 0,
                y: configuration.isOn ? 1 : 0
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

extension ToggleStyle where Self == SolidToggleStyle {
    static var solid: SolidToggleStyle {
        SolidToggleStyle()
    }
    
    static func solid(size: ControlSize = .regular) -> SolidToggleStyle {
        SolidToggleStyle(size: size)
    }
}
