//
//  DocumentBoundsOverlay.swift
//  Codex Scanner
//
//  Created by Aaron Aalto on 12/29/25.
//

import SwiftUI

/// Overlay that displays detected document bounds with corner indicators and stability progress
struct DocumentBoundsOverlay: View {
    let bounds: ImageProcessor.DocumentBounds?
    let viewSize: CGSize
    let stabilityProgress: Double
    let isScanning: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if let bounds = bounds {
                let size = viewSize
                
                // Convert normalized coordinates to view coordinates
                let topLeft = CGPoint(
                    x: bounds.topLeft.x * size.width,
                    y: (1 - bounds.topLeft.y) * size.height
                )
                let topRight = CGPoint(
                    x: bounds.topRight.x * size.width,
                    y: (1 - bounds.topRight.y) * size.height
                )
                let bottomLeft = CGPoint(
                    x: bounds.bottomLeft.x * size.width,
                    y: (1 - bounds.bottomLeft.y) * size.height
                )
                let bottomRight = CGPoint(
                    x: bounds.bottomRight.x * size.width,
                    y: (1 - bounds.bottomRight.y) * size.height
                )
                
                // Document outline
                Path { path in
                    path.move(to: topLeft)
                    path.addLine(to: topRight)
                    path.addLine(to: bottomRight)
                    path.addLine(to: bottomLeft)
                    path.closeSubpath()
                }
                .stroke(
                    isScanning ? Color(hex: "4F46E5") : Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color(hex: "4F46E5").opacity(isScanning ? 0.5 : 0), radius: 8)
                
                // Corner indicators
                ForEach(Array([topLeft, topRight, bottomLeft, bottomRight].enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(isScanning ? Color(hex: "4F46E5") : .white.opacity(0.8))
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .position(point)
                }
                
                // Stability indicator
                if stabilityProgress > 0 && isScanning {
                    let center = CGPoint(
                        x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4,
                        y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4
                    )
                    
                    Circle()
                        .trim(from: 0, to: stabilityProgress)
                        .stroke(Color(hex: "4F46E5"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .position(center)
                        .shadow(color: Color(hex: "4F46E5").opacity(0.5), radius: 8)
                }
            }
        }
    }
}
