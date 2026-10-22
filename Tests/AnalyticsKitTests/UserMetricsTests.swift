import XCTest
@testable import AnalyticsKit

@MainActor
final class UserMetricsTests: XCTestCase {
    func testStartSetsInstallCohortAndFirstSession() {
        let harness = Harness()
        harness.analytics.start()

        XCTAssertEqual(harness.analytics.state.sessionCount, 1)
        XCTAssertEqual(harness.analytics.state.activeDayCount, 1)
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.installCohort], "2026-09-21")
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.sessionBucket], "1")
        XCTAssertEqual(harness.provider.userProperties[AnalyticsUserProperty.userTier], "free")
        XCTAssertTrue(harness.provider.events(named: "retention_d0").isEmpty)
    }

    func testShortBackgroundDoesNotStartNewSession() {
        let harness = Harness()
        harness.analytics.start()
        harness.analytics.appDidEnterBackground()
        harness.clock.advance(seconds: 60)
        harness.analytics.appDidBecomeActive()

        XCTAssertEqual(harness.analytics.state.sessionCount, 1)
    }

    func testRetentionMilestonesAreLoggedOncePerDay() {
        let harness = Harness()
        harness.analytics.start()

        harness.newSession(afterDays: 1)
        harness.analytics.appDidEnterBackground()
        harness.clock.advance(seconds: 3600)
        harness.analytics.appDidBecomeActive()
        harness.newSession(afterDays: 1)
        harness.newSession(afterDays: 1)

        XCTAssertEqual(harness.provider.events(named: "retention_d1").count, 1)
        XCTAssertEqual(harness.provider.last("retention_d1")?[AnalyticsParameter.sessionNumber], 2)
        XCTAssertTrue(harness.provider.events(named: "retention_d2").isEmpty)
        XCTAssertEqual(harness.provider.events(named: "retention_d3").count, 1)
        XCTAssertEqual(harness.analytics.metrics.sessionCount, 5)
        XCTAssertEqual(harness.analytics.metrics.activeDayCount, 4)
        XCTAssertEqual(harness.analytics.metrics.daysSinceInstall, 3)
    }

    func testStatePersistsAcrossLaunches() {
        let harness = Harness()
        harness.analytics.start()
        harness.newSession(afterDays: 1)

        let relaunched = AnalyticsManager(configuration: harness.analytics.configuration, providers: [harness.provider], store: harness.store, clock: harness.clock)
        relaunched.start()

        XCTAssertEqual(relaunched.state.sessionCount, 3)
        XCTAssertEqual(harness.provider.events(named: "retention_d1").count, 1)
    }

    func testFunnelAndScreenEvents() {
        let harness = Harness()
        harness.analytics.trackOnboardingStep(1, name: "welcome")
        harness.analytics.trackOnboardingStep(2, name: "permissions")
        harness.analytics.trackOnboardingComplete()
        harness.analytics.trackScreen("Home")
        harness.analytics.setExperiment("paywall_copy", variant: "b")

        XCTAssertEqual(harness.provider.events.map(\.name), ["tutorial_begin", "onboarding_step", "onboarding_step", "tutorial_complete", "screen_view"])
        XCTAssertEqual(harness.provider.last("screen_view")?[AnalyticsParameter.screenName], "Home")
        XCTAssertEqual(harness.provider.userProperties["exp_paywall_copy"], "b")
    }

    func testEventHandlerReceivesSanitizedEvents() {
        let harness = Harness()
        var received: [String] = []
        var issues: [String] = []
        harness.analytics.eventHandler = { received.append($0.name) }
        harness.analytics.issueHandler = { issues.append($0) }

        harness.analytics.track("session_start")
        harness.analytics.track("level up")

        XCTAssertEqual(received, ["level_up"])
        XCTAssertEqual(issues.count, 2)
    }
}
