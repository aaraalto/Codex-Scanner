//
//  DocumentBoundsOverlay.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Overlay that displays detected document bounds with liquid glass styling
/// Features smooth animations, draggable corner handles, and glassmorphic effects
struct DocumentBoundsOverlay: View {
    let bounds: ImageProcessor.DocumentBounds?
    let viewSize: CGSize
    let stabilityProgress: Double
    let isScanning: Bool
    let statusText: String
    let onCornerDrag: ((ScannerViewModel.Corner, CGPoint) -> Void)?
    
    @State private var activeCorner: ScannerViewModel.Corner?
    @State private var cornerHover: ScannerViewModel.Corner?
    
    // Design constants - Liquid Glass
    private let glassColor = Color.white
    private let accentGradient = LinearGradient(
        colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let cornerHandleSize: CGFloat = 24
    private let cornerHitAreaSize: CGFloat = 44
    
    init(
        bounds: ImageProcessor.DocumentBounds?,
        viewSize: CGSize,
        stabilityProgress: Double,
        isScanning: Bool,
        statusText: String = "Hold Steady…",
        onCornerDrag: ((ScannerViewModel.Corner, CGPoint) -> Void)? = nil
    ) {
        self.bounds = bounds
        self.viewSize = viewSize
        self.stabilityProgress = stabilityProgress
        self.isScanning = isScanning
        self.statusText = statusText
        self.onCornerDrag = onCornerDrag
    }
    
    var body: some View {
        GeometryReader { geometry in
            if let bounds = bounds {
                let size = viewSize
                
                // Convert normalized coordinates to view coordinates
                let corners = convertedCorners(bounds: bounds, size: size)
                
                // Liquid glass fill
                liquidGlassFill(corners: corners)
                
                // Glowing border
                glowingBorder(corners: corners)
                
                // Draggable corner handles
                cornerHandles(corners: corners, size: size)
                
                // Status pill with glass effect
                if isScanning {
                    statusPill(corners: corners)
                }
                
                // Stability ring with glow
                if stabilityProgress > 0 && isScanning {
                    stabilityRing(corners: corners)
                }
            }
        }
        .animation(.easeOut(duration: 0.08), value: bounds?.topLeft.x)
        .animation(.easeOut(duration: 0.08), value: bounds?.topLeft.y)
    }
    
    // MARK: - Subviews
    
    private func liquidGlassFill(corners: CornerPoints) -> some View {
        Path { path in
            path.move(to: corners.topLeft)
            path.addLine(to: corners.topRight)
            path.addLine(to: corners.bottomRight)
            path.addLine(to: corners.bottomLeft)
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.cyan.opacity(0.05),
                    Color.white.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .blur(radius: 0.5)
    }
    
    private func glowingBorder(corners: CornerPoints) -> some View {
        ZStack {
            // Outer glow
            Path { path in
                path.move(to: corners.topLeft)
                path.addLine(to: corners.topRight)
                path.addLine(to: corners.bottomRight)
                path.addLine(to: corners.bottomLeft)
                path.closeSubpath()
            }
            .stroke(
                LinearGradient(
                    colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 4
            )
            .blur(radius: 8)
            
            // Inner crisp border
            Path { path in
                path.move(to: corners.topLeft)
                path.addLine(to: corners.topRight)
                path.addLine(to: corners.bottomRight)
                path.addLine(to: corners.bottomLeft)
                path.closeSubpath()
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.9),
                        Color.cyan.opacity(0.7),
                        Color.white.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
        }
    }
    
    private func cornerHandles(corners: CornerPoints, size: CGSize) -> some View {
        let cornerData: [(ScannerViewModel.Corner, CGPoint)] = [
            (.topLeft, corners.topLeft),
            (.topRight, corners.topRight),
            (.bottomLeft, corners.bottomLeft),
            (.bottomRight, corners.bottomRight)
        ]
        
        return ForEach(cornerData, id: \.0) { corner, point in
            cornerHandle(for: corner, at: point, size: size)
        }
    }
    
    private func cornerHandle(for corner: ScannerViewModel.Corner, at point: CGPoint, size: CGSize) -> some View {
        let isActive = activeCorner == corner
        let isHovered = cornerHover == corner
        let scale: CGFloat = isActive ? 1.3 : (isHovered ? 1.15 : 1.0)
        
        return ZStack {
            // Outer glow when active
            if isActive || isHovered {
                Circle()
                    .fill(Color.cyan.opacity(0.4))
                    .frame(width: cornerHandleSize * 2, height: cornerHandleSize * 2)
                    .blur(radius: 12)
            }
            
            // Glass handle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: cornerHandleSize, height: cornerHandleSize)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.9), Color.cyan.opacity(0.3)],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: cornerHandleSize
                            )
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white, Color.cyan.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.cyan.opacity(0.5), radius: isActive ? 12 : 6)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .scaleEffect(scale)
        .position(point)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: scale)
        .onHover { hovering in
            cornerHover = hovering ? corner : nil
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    activeCorner = corner
                    // Convert drag location to normalized coordinates
                    let normalized = CGPoint(
                        x: value.location.x / size.width,
                        y: 1 - (value.location.y / size.height)
                    )
                    onCornerDrag?(corner, normalized)
                }
                .onEnded { _ in
                    activeCorner = nil
                }
        )
        .allowsHitTesting(onCornerDrag != nil)
    }
    
    private func statusPill(corners: CornerPoints) -> some View {
        let bottomCenter = CGPoint(
            x: (corners.bottomLeft.x + corners.bottomRight.x) / 2,
            y: max(corners.bottomLeft.y, corners.bottomRight.y) + 40
        )
        
        return Text(statusText)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .position(bottomCenter)
    }
    
    private func stabilityRing(corners: CornerPoints) -> some View {
        let center = CGPoint(
            x: (corners.topLeft.x + corners.topRight.x + corners.bottomLeft.x + corners.bottomRight.x) / 4,
            y: (corners.topLeft.y + corners.topRight.y + corners.bottomLeft.y + corners.bottomRight.y) / 4
        )
        
        return ZStack {
            // Glow background
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 70, height: 70)
                .blur(radius: 15)
            
            // Background ring (glass)
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            // Progress ring
            Circle()
                .trim(from: 0, to: stabilityProgress)
                .stroke(
                    LinearGradient(
                        colors: [Color.green, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.green.opacity(0.6), radius: 8)
            
            // Percentage text
            Text("\(Int(stabilityProgress * 100))")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
        .position(center)
    }
    
    // MARK: - Helpers
    
    private struct CornerPoints {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
    }
    
    private func convertedCorners(bounds: ImageProcessor.DocumentBounds, size: CGSize) -> CornerPoints {
        CornerPoints(
            topLeft: CGPoint(
                x: bounds.topLeft.x * size.width,
                y: (1 - bounds.topLeft.y) * size.height
            ),
            topRight: CGPoint(
                x: bounds.topRight.x * size.width,
                y: (1 - bounds.topRight.y) * size.height
            ),
            bottomLeft: CGPoint(
                x: bounds.bottomLeft.x * size.width,
                y: (1 - bounds.bottomLeft.y) * size.height
            ),
            bottomRight: CGPoint(
                x: bounds.bottomRight.x * size.width,
                y: (1 - bounds.bottomRight.y) * size.height
            )
        )
    }
}

// MARK: - Hashable conformance for Corner iteration
extension ScannerViewModel.Corner: Hashable {}
