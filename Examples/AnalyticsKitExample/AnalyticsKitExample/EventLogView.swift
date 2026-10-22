import AnalyticsKit
import SwiftUI

struct EventLogView: View {
    @EnvironmentObject private var analytics: AnalyticsManager
    @EnvironmentObject private var log: InMemoryAnalyticsProvider
    @State private var filter = ""

    private var events: [(offset: Int, element: AnalyticsEvent)] {
        let all = Array(log.events.enumerated()).reversed()
        guard !filter.isEmpty else { return Array(all) }
        return all.filter { $0.element.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        NavigationStack {
            List(events, id: \.offset) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.element.name)
                        .font(.headline.monospaced())
                    ForEach(item.element.parameters.sorted { $0.key < $1.key }, id: \.key) { key, value in
                        Text("\(key): \(value.description)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .overlay {
                if log.events.isEmpty {
                    Text("No events yet").foregroundStyle(.secondary)
                }
            }
            .searchable(text: $filter, prompt: "Filter by event name")
            .navigationTitle("Events (\(log.events.count))")
            .trackScreen("EventLog", analytics: analytics)
        }
    }
}
