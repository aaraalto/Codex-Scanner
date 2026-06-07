import Testing
@testable import Codex_Scanner

struct BookCoverTests {
    @Test func emptyBookHasNoCover() {
        let book = Book(title: "Empty")
        #expect(book.coverPage == nil)
    }

    @Test func coverIsFirstPageInOrder() {
        let book = Book(title: "Three")
        let p0 = Page(imagePath: "a.jpg", order: 2)
        let p1 = Page(imagePath: "b.jpg", order: 0)
        let p2 = Page(imagePath: "c.jpg", order: 1)
        book.pages = [p0, p1, p2]
        #expect(book.coverPage?.imagePath == "b.jpg")
    }
}
