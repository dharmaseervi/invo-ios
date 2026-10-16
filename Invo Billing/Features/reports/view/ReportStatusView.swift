import SwiftUI

struct ReportStatusView: View {
    let message: String
    let hasData: Bool
    let retry: () async -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(hasData ? "Refresh failed · showing previous figures" : "Report unavailable", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Button("Retry") { Task { await retry() } }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityElement(children: .contain)
    }
}
