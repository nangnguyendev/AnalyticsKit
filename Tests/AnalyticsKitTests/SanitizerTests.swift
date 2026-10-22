import XCTest
@testable import AnalyticsKit

final class SanitizerTests: XCTestCase {
    private let sanitizer = AnalyticsSanitizer()

    func testDropsReservedEventNames() {
        var issues: [String] = []
        XCTAssertNil(sanitizer.sanitize(AnalyticsEvent("ad_click"), issues: &issues))
        XCTAssertNil(sanitizer.sanitize(AnalyticsEvent("firebase_custom"), issues: &issues))
        XCTAssertEqual(issues.count, 2)
    }

    func testCleansInvalidCharactersAndLeadingDigits() {
        var issues: [String] = []
        let event = sanitizer.sanitize(AnalyticsEvent("1 Paywall-View!", parameters: ["screen name": "home"]), issues: &issues)
        XCTAssertEqual(event?.name, "Paywall_View_")
        XCTAssertEqual(event?["screen_name"], "home")
    }

    func testTruncatesLongNamesAndValues() {
        var issues: [String] = []
        let longName = String(repeating: "a", count: 60)
        let longValue = String(repeating: "x", count: 150)
        let event = sanitizer.sanitize(AnalyticsEvent(longName, parameters: ["text": .string(longValue)]), issues: &issues)
        XCTAssertEqual(event?.name.count, AnalyticsLimits.maxEventNameLength)
        XCTAssertEqual(event?["text"]?.stringValue?.count, AnalyticsLimits.maxParameterStringLength)
    }

    func testKeepsAtMostTwentyFiveParameters() {
        var issues: [String] = []
        var parameters: [String: AnalyticsValue?] = [:]
        for index in 0..<30 { parameters["p\(index)"] = .int(index) }
        let event = sanitizer.sanitize(AnalyticsEvent("many", parameters: parameters), issues: &issues)
        XCTAssertEqual(event?.parameters.count, 25)
        XCTAssertEqual(issues.count, 5)
    }

    func testUserPropertyLimits() {
        var issues: [String] = []
        XCTAssertNil(sanitizer.sanitizeUserProperty(name: "user_id", value: "1", issues: &issues))
        let result = sanitizer.sanitizeUserProperty(name: "very_long_user_property_name_here", value: String(repeating: "v", count: 50), issues: &issues)
        XCTAssertEqual(result?.name.count, AnalyticsLimits.maxUserPropertyNameLength)
        XCTAssertEqual(result?.value?.count, AnalyticsLimits.maxUserPropertyValueLength)
    }

    func testBucketLabels() {
        let edges: [Decimal] = [0.1, 0.5, 1, 5]
        XCTAssertEqual(AnalyticsBucket.label(for: Decimal(0), edges: edges), "0")
        XCTAssertEqual(AnalyticsBucket.label(for: Decimal(string: "0.05")!, edges: edges), "0-0.1")
        XCTAssertEqual(AnalyticsBucket.label(for: Decimal(string: "0.7")!, edges: edges), "0.5-1")
        XCTAssertEqual(AnalyticsBucket.label(for: Decimal(12), edges: edges), "5+")
        XCTAssertEqual(AnalyticsBucket.label(for: 1, edges: [1, 3, 7]), "1")
        XCTAssertEqual(AnalyticsBucket.label(for: 5, edges: [1, 3, 7]), "4-7")
        XCTAssertEqual(AnalyticsBucket.label(for: 9, edges: [1, 3, 7]), "8+")
    }
}
