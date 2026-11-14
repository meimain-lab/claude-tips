import Testing
@testable import TipsCore

@Test func versionIsSet() {
    #expect(!TipsCore.version.isEmpty)
}
