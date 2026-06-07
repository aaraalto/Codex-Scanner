import Testing
import CoreImage
@testable import Codex_Scanner

@MainActor
struct ScannerModelTests {
    private func makeCapturedPage() -> CapturedPage {
        let image = CIImage(color: .gray).cropped(to: CGRect(x: 0, y: 0, width: 10, height: 10))
        return CapturedPage(
            originalImage: image,
            processedImage: image,
            bounds: nil,
            preset: .original,
            processingMode: .mixed,
            thumbnail: nil
        )
    }

    @Test func startsIdle() {
        let model = ScannerModel()
        #expect(model.phase == .idle)
    }

    @Test func removePageRemovesMatch() {
        let model = ScannerModel()
        let a = makeCapturedPage()
        let b = makeCapturedPage()
        model.capturedPages = [a, b]
        model.removePage(a)
        #expect(model.capturedPages.count == 1)
        #expect(model.capturedPages.first?.id == b.id)
    }

    @Test func clearAllPagesEmptiesList() {
        let model = ScannerModel()
        model.capturedPages = [makeCapturedPage(), makeCapturedPage()]
        model.clearAllPages()
        #expect(model.capturedPages.isEmpty)
    }
}
