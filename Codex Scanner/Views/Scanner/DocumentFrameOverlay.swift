//
//  DocumentFrameOverlay.swift
//  Codex Scanner
//
//  Draws detected document bounds over the live camera feed.
//

import SwiftUI

struct DocumentFrameOverlay: View {
    let bounds: ImageProcessor.DocumentBounds
    let viewSize: CGSize

    var body: some View {
        Canvas { context, size in
            let tl = denormalize(bounds.topLeft, in: size)
            let tr = denormalize(bounds.topRight, in: size)
            let bl = denormalize(bounds.bottomLeft, in: size)
            let br = denormalize(bounds.bottomRight, in: size)

            var document = Path()
            document.move(to: tl)
            document.addLine(to: tr)
            document.addLine(to: br)
            document.addLine(to: bl)
            document.closeSubpath()

            // Dim everything outside the detected document.
            let full = Path(CGRect(origin: .zero, size: size))
            context.fill(full.subtracting(document), with: .color(Color.scannerScrim))

            // Crisp frame.
            context.stroke(document, with: .color(Color.scannerBorder), lineWidth: 1.5)

            // Corner dots.
            for point in [tl, tr, bl, br] {
                let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(Color.scannerHandle))
            }
        }
        .allowsHitTesting(false)
    }

    /// Vision coordinates are normalized with origin bottom-left; flip Y for the view.
    private func denormalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
    }
}

#Preview {
    DocumentFrameOverlay(
        bounds: ImageProcessor.DocumentBounds(
            topLeft: CGPoint(x: 0.12, y: 0.9),
            topRight: CGPoint(x: 0.88, y: 0.9),
            bottomLeft: CGPoint(x: 0.12, y: 0.1),
            bottomRight: CGPoint(x: 0.88, y: 0.1),
            confidence: 1
        ),
        viewSize: CGSize(width: 400, height: 300)
    )
    .frame(width: 400, height: 300)
    .background(.black)
}
