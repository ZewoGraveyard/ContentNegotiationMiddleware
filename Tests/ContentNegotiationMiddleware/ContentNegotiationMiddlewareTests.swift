import XCTest
@testable import ContentNegotiationMiddleware

class ContentNegotiationMiddlewareTests: XCTestCase {
    func testReality() {
        XCTAssert(2 + 2 == 4, "Something is severely wrong here.")
    }
}

extension ContentNegotiationMiddlewareTests {
    static var allTests : [(String, ContentNegotiationMiddlewareTests -> () throws -> Void)] {
        return [
           ("testReality", testReality),
        ]
    }
}
