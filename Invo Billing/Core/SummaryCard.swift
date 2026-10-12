import SwiftUI

/// The headline figure at the top of a list screen: a caption, one large amount,
/// optional supporting lines, then the figures behind it in an ``AdaptiveStatRow``.
struct SummaryCard<Detail: View>: View {
    let title: String
    let value: String
    var valueColor: Color = .sForeground
    var stats: [AdaptiveStatRow.Stat] = []
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value).moneyLine()
                    .font(.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                detail
            }

            if !stats.isEmpty {
                Divider()
                AdaptiveStatRow(stats: stats)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

extension SummaryCard where Detail == EmptyView {
    init(title: String, value: String, valueColor: Color = .sForeground, stats: [AdaptiveStatRow.Stat] = []) {
        self.init(title: title, value: value, valueColor: valueColor, stats: stats) { EmptyView() }
    }
}

extension View {
    /// Places a full-width card (summary, filters) as a borderless row at the top of a plain List.
    func listHeaderRow(top: CGFloat = 8, bottom: CGFloat = 4, horizontal: CGFloat = AppSpacing.page) -> some View {
        self
            .padding(.horizontal, horizontal)
            .padding(.top, top)
            .padding(.bottom, bottom)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// The standard inset for a data row in the app's plain lists.
    func standardListRow(trailing: CGFloat = 20) -> some View {
        listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: trailing))
    }
}
