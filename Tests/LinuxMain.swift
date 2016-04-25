#if os(Linux)

import XCTest
@testable import ContentNegotiationMiddlewareTestSuite

XCTMain([
    testCase(ContentNegotiationMiddlewareTests.allTests)
])

#endif
