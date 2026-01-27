//
//  DocumentBoundsOverlay.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Overlay that displays detected document bounds with elegant styling
/// Features dark mask outside bounds, smooth animations, and refined corner handles
struct DocumentBoundsOverlay: View {
    let bounds: ImageProcessor.DocumentBounds?
    let viewSize: CGSize
    let stabilityProgress: Double
    let isScanning: Bool
    let statusText: String
    let onCornerDrag: ((ScannerViewModel.Corner, CGPoint) -> Void)?
    
    @State private var activeCorner: ScannerViewModel.Corner?
    @State private var cornerHover: ScannerViewModel.Corner?
    
    // Design constants - Small by default, grow on interaction
    private let cornerHandleSizeDefault: CGFloat = 10
    private let cornerHandleSizeHover: CGFloat = 16
    private let cornerHandleSizeActive: CGFloat = 20
    private let maskOpacity: Double = 0.65
    
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
            let size = viewSize
            
            if let bounds = bounds {
                // Convert normalized coordinates to view coordinates
                let corners = convertedCorners(bounds: bounds, size: size)
                
                // Dark mask outside document bounds
                outsideMask(corners: corners, size: size)
                
                // Minimal elegant border
                elegantBorder(corners: corners)
                
                // Draggable corner handles
                cornerHandles(corners: corners, size: size)
                
                // Stability indicator (minimal)
                if stabilityProgress > 0 && isScanning {
                    stabilityIndicator(corners: corners)
                }
            } else {
                // No bounds detected - show subtle full-screen dim
                Rectangle()
                    .fill(Color.black.opacity(0.3))
            }
        }
        .animation(.easeOut(duration: 0.12), value: bounds?.topLeft.x)
        .animation(.easeOut(duration: 0.12), value: bounds?.topLeft.y)
    }
    
    // MARK: - Outside Mask (dims everything except document)
    
    private func outsideMask(corners: CornerPoints, size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Full screen dark rect
            var fullPath = Path()
            fullPath.addRect(CGRect(origin: .zero, size: canvasSize))
            
            // Document cutout (inverted)
            var documentPath = Path()
            documentPath.move(to: corners.topLeft)
            documentPath.addLine(to: corners.topRight)
            documentPath.addLine(to: corners.bottomRight)
            documentPath.addLine(to: corners.bottomLeft)
            documentPath.closeSubpath()
            
            // Draw the mask with eo fill rule to cut out document area
            context.fill(
                fullPath.subtracting(documentPath),
                with: .color(Color.black.opacity(maskOpacity))
            )
        }
        .allowsHitTesting(false)
    }
    
    private func elegantBorder(corners: CornerPoints) -> some View {
        ZStack {
            // Subtle outer glow
            Path { path in
                path.move(to: corners.topLeft)
                path.addLine(to: corners.topRight)
                path.addLine(to: corners.bottomRight)
                path.addLine(to: corners.bottomLeft)
                path.closeSubpath()
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 3)
            .blur(radius: 4)
            
            // Crisp white border
            Path { path in
                path.move(to: corners.topLeft)
                path.addLine(to: corners.topRight)
                path.addLine(to: corners.bottomRight)
                path.addLine(to: corners.bottomLeft)
                path.closeSubpath()
            }
            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
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
        
        // Size grows based on state
        let handleSize: CGFloat = isActive ? cornerHandleSizeActive : (isHovered ? cornerHandleSizeHover : cornerHandleSizeDefault)
        
        return ZStack {
            // Outer glow ring when active or hovered
            if isActive || isHovered {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: handleSize + 16, height: handleSize + 16)
                    .blur(radius: 6)
            }
            
            // Main handle - grows smoothly
            Circle()
                .fill(Color.white)
                .frame(width: handleSize, height: handleSize)
                .shadow(color: .black.opacity(isActive ? 0.5 : 0.35), radius: isActive ? 8 : 4, y: 2)
        }
        .position(point)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            cornerHover = hovering ? corner : nil
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    activeCorner = corner
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
    
    private func stabilityIndicator(corners: CornerPoints) -> some View {
        // Place indicator at top of document
        let topCenter = CGPoint(
            x: (corners.topLeft.x + corners.topRight.x) / 2,
            y: min(corners.topLeft.y, corners.topRight.y) - 48
        )
        
        return HStack(spacing: 10) {
            // Standard Mac slider
            Slider(value: .constant(stabilityProgress), in: 0...1)
                .frame(width: 80)
                .disabled(true)
            
            // Percentage
            Text("\(Int(stabilityProgress * 100))%")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .position(topCenter)
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
