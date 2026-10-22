#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
private struct ScreenTrackingModifier: ViewModifier {
    let analytics: AnalyticsManager
    let name: String
    let screenClass: String?

    func body(content: Content) -> some View {
        content.onAppear { analytics.trackScreen(name, screenClass: screenClass) }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public extension View {
    func trackScreen(_ name: String, screenClass: String? = nil, analytics: AnalyticsManager) -> some View {
        modifier(ScreenTrackingModifier(analytics: analytics, name: name, screenClass: screenClass))
    }
}
#endif
