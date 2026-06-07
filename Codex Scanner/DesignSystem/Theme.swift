//
//  Theme.swift
//  Codex Scanner
//
//  Native macOS design-token foundation.
//
//  This is the single source of truth for color, spacing, radius, and type.
//  It is intentionally additive: the legacy `Color.notion*` tokens and the
//  hand-rolled `Notion*` control styles still exist so nothing breaks. Views
//  are migrated onto these tokens incrementally.
//
//  Design intent (see project memory `project-direction`):
//   - Target a native macOS (Tahoe) look. Prefer system semantic colors so the
//     UI adapts to Light/Dark, the user's accent color, and Increase Contrast.
//   - Identity values (brand accent, type choices) are placeholders to be tuned
//     from the Sketch designs, which are used as inspiration, not a spec.
//

import SwiftUI
import AppKit

// MARK: - Adaptive Color Helper

extension Color {
    /// A color that resolves differently in Light vs Dark appearance on macOS.
    ///
    /// Use this only for *brand* colors that aren't covered by a system semantic
    /// color. For anything the system already defines (labels, backgrounds,
    /// separators, status colors), prefer the semantic tokens below — they adapt
    /// automatically and respect accessibility settings.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua: return NSColor(dark)
            default:        return NSColor(light)
            }
        })
    }
}

// MARK: - Semantic Color Tokens

extension Color {

    // Surfaces & backgrounds — system colors that already adapt to appearance.

    /// The window/canvas background. Equivalent to the app's base layer.
    static let appBackground = Color(nsColor: .windowBackgroundColor)
    /// A recessed content area (e.g. the preview/scan stage behind a page).
    static let appContentBackground = Color(nsColor: .underPageBackgroundColor)
    /// A raised surface for controls, cards, and panels.
    static let appSurface = Color(nsColor: .controlBackgroundColor)
    /// A hovered/elevated control surface (opaque, adaptive).
    static let appSurfaceHover = Color(light: Color(white: 0.91), dark: Color(white: 0.25))
    /// Hairline separators and control borders.
    static let appBorder = Color(nsColor: .separatorColor)

    // Text — map to system label colors so contrast is always correct.

    static let appTextPrimary = Color(nsColor: .labelColor)
    static let appTextSecondary = Color(nsColor: .secondaryLabelColor)
    static let appTextTertiary = Color(nsColor: .tertiaryLabelColor)

    // Accent & brand.

    /// The interactive accent. Defaults to the user's system accent so the app
    /// feels native. Swap to `appBrand` only if the Sketch identity calls for a
    /// fixed brand color.
    static let appAccent = Color.accentColor
    /// Accent in a hover state — a subtle shift from `appAccent` for pointer hover.
    static let appAccentHover = Color(light: Color(hex: "1F5BFF"), dark: Color(hex: "6E9BF0"))
    /// Placeholder brand accent (tune from the Sketch designs). Defined as an
    /// adaptive pair so it reads well in both appearances.
    static let appBrand = Color(light: Color(hex: "2F6BFF"), dark: Color(hex: "5B8DEF"))

    // Status.

    static let appSuccess = Color(nsColor: .systemGreen)
    static let appWarning = Color(nsColor: .systemOrange)
    static let appDestructive = Color(nsColor: .systemRed)

    // Scanner-over-video tokens.
    //
    // Controls drawn on top of the live camera feed must stay legible regardless
    // of system appearance, so these are intentionally fixed (not appearance-
    // adaptive). They centralize the white/black scrim values currently spread
    // across ScannerView and DocumentBoundsOverlay.

    /// Crisp edge for the document-bounds frame on top of video.
    static let scannerBorder = Color.white.opacity(0.9)
    /// Dimming scrim outside the detected document.
    static let scannerScrim = Color.black.opacity(0.65)
    /// Draggable corner handle fill.
    static let scannerHandle = Color.white
    /// Background for floating glassless control chips over video.
    static let scannerControlBackground = Color.black.opacity(0.55)
}

// MARK: - Design Tokens

/// Namespace for non-color design tokens.
enum Theme {

    /// 4pt-based spacing scale. Replaces the ad-hoc 2/5/6/8/10/12/16/20/24 values.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    /// Corner-radius scale. Replaces the ad-hoc 4/5/6/7/8/10 values.
    /// All app shapes should use `.continuous` style with these.
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
        /// Fully rounded (capsule) — clamp at runtime via `Capsule()` instead
        /// where possible; this is for rounded-rect call sites that need it.
        static let pill: CGFloat = 999
    }

    /// Semantic text ramp — the single source of truth for the scanner's type.
    ///
    /// Values currently mirror the sizes/weights already in use so centralizing
    /// causes no visual change; tuning the type *identity* (e.g. from the Sketch
    /// designs, or moving to Dynamic-Type text styles) now happens here in one
    /// place instead of across dozens of call sites.
    enum Typography {
        /// Inline control/title labels (e.g. the editable book title).
        static let controlLabel = Font.system(size: 13, weight: .medium)
        /// Prominent action-button labels.
        static let action = Font.system(size: 13, weight: .semibold)
        /// Over-video badges (e.g. the zoom factor).
        static let badge = Font.system(size: 14, weight: .semibold)
        /// Secondary values and placeholders.
        static let secondary = Font.system(size: 14, weight: .medium)
        /// Small captions / sublabels.
        static let caption = Font.system(size: 12, weight: .medium)
        /// Celebration moment (e.g. the "Saved!" confirmation).
        static let celebration = Font.system(size: 18, weight: .bold, design: .rounded)
        /// Compact rounded title (e.g. a generated book-cover title).
        static let coverTitle = Font.system(size: 11, weight: .semibold, design: .rounded)
        /// Monospaced counter that must not jitter in width (page navigation).
        static let counter = Font.system(size: 14, weight: .medium).monospacedDigit()
    }

    /// Standard animation curves so motion feels consistent app-wide.
    enum Motion {
        /// Snappy UI state changes (mode swaps, control reveals).
        static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
        /// Larger content transitions (scanning <-> preview).
        static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.85)
        /// Quick fades.
        static let fade = Animation.easeOut(duration: 0.2)
    }
}

// MARK: - Elevation

extension View {
    /// Subtle shadow for raised cards and panels.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
    }

    /// Stronger shadow for controls floating over the camera feed.
    func floatingShadow() -> some View {
        shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
