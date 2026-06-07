import Testing
@testable import Codex_Scanner

struct RouteTests {
    @Test func scanEqualsScan() {
        #expect(Route.scan == Route.scan)
    }

    @Test func scanNotEqualBook() {
        let book = Book(title: "A")
        #expect(Route.scan != Route.book(book))
    }

    @Test func differentBooksAreNotEqual() {
        let a = Book(title: "A")
        let b = Book(title: "B")
        #expect(Route.book(a) != Route.book(b))
    }
}
