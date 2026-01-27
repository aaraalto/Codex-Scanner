//
//  NotionButtonStyles.swift
//  Codex Scanner
//
//  Notion dark mode-inspired button styles for consistent visual design
//

import SwiftUI

// MARK: - Notion Design Tokens

extension Color {
    /// Notion dark mode background colors
    static let notionBackground = Color(hex: "1E1E1E")
    static let notionSurface = Color(hex: "2D2D2D")
    static let notionSurfaceHover = Color(hex: "373737")
    static let notionBorder = Color(hex: "3D3D3D")
    static let notionBorderSubtle = Color(hex: "2D2D2D")
    
    /// Notion text colors
    static let notionTextPrimary = Color(hex: "FFFFFF")
    static let notionTextSecondary = Color(hex: "B3B3B3")
    static let notionTextTertiary = Color(hex: "808080")
    
    /// Notion accent (subtle blue-gray)
    static let notionAccent = Color(hex: "4A90E2")
    static let notionAccentHover = Color(hex: "5BA0F2")
}

// MARK: - Notion Primary Button Style

struct NotionPrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.notionAccentHover : Color.notionAccent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Notion Secondary Button Style

struct NotionSecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.notionTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.notionSurfaceHover : Color.notionSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.notionBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 1, y: 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Notion Borderless Button Style

struct NotionBorderlessButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.notionTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.notionSurfaceHover.opacity(0.6) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Notion Icon Button Style

struct NotionIconButtonStyle: ButtonStyle {
    @State private var isHovered = false
    var size: CGFloat = 32
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.notionTextSecondary)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.notionSurfaceHover.opacity(0.6) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == NotionPrimaryButtonStyle {
    static var notionPrimary: NotionPrimaryButtonStyle {
        NotionPrimaryButtonStyle()
    }
}

extension ButtonStyle where Self == NotionSecondaryButtonStyle {
    static var notionSecondary: NotionSecondaryButtonStyle {
        NotionSecondaryButtonStyle()
    }
}

extension ButtonStyle where Self == NotionBorderlessButtonStyle {
    static var notionBorderless: NotionBorderlessButtonStyle {
        NotionBorderlessButtonStyle()
    }
}

extension ButtonStyle where Self == NotionIconButtonStyle {
    static func notionIcon(size: CGFloat = 32) -> NotionIconButtonStyle {
        NotionIconButtonStyle(size: size)
    }
}
