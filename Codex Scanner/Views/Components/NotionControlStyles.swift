//
//  NotionControlStyles.swift
//  Codex Scanner
//
//  Notion dark mode-inspired control styles (pickers, text fields, etc.)
//

import SwiftUI

// MARK: - Notion Text Field Style

struct NotionTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.notionSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.notionBorder, lineWidth: 0.5)
            )
            .foregroundStyle(Color.notionTextPrimary)
    }
}

extension TextFieldStyle where Self == NotionTextFieldStyle {
    static var notion: NotionTextFieldStyle {
        NotionTextFieldStyle()
    }
}

// MARK: - Notion Segmented Picker Modifier

extension View {
    /// Applies Notion dark mode styling to segmented pickers
    func notionSegmentedPicker() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.notionSurface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.notionBorder.opacity(0.5), lineWidth: 0.5)
            )
    }
}
