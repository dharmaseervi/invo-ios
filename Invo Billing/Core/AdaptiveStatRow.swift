//
//  AdaptiveStatRow.swift
//  Invo Billing
//

import SwiftUI

/// A row of summary figures that becomes a list when it no longer fits.
///
/// All three reports put their totals in a fixed horizontal row — three columns on the
/// stock report, four on GST, five on the ageing report. At an accessibility text size
/// none of them fit: values truncated to "₹14,36,51…", labels broke into "Curre / nt",
/// and two amounts ran together as "₹1,512.00₹1,512.00" with no gap between them. A
/// summary that cannot be read is worse than no summary.
///
/// `ViewThatFits` picks the horizontal layout while it genuinely fits and falls back to
/// a vertical list when it does not, so nothing truncates at any text size.
struct AdaptiveStatRow: View {
    struct Stat: Identifiable {
        let label: String
        let value: String
        var color: Color = .sForeground
        var id: String { label }
    }

    let stats: [Stat]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontal
            vertical
        }
    }

    private var horizontal: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    Rectangle().fill(Color.sBorder).frame(width: 0.5, height: 30)
                }
                column(stat)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, index == 0 ? 0 : 10)
            }
        }
    }

    private var vertical: some View {
        VStack(spacing: 10) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    Rectangle().fill(Color.sBorder).frame(height: 0.5)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(stat.label)
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                    Spacer(minLength: 12)
                    Text(stat.value)
                        .font(.scaled(14, weight: .semibold))
                        .foregroundColor(stat.color)
                        .moneyLine()
                }
            }
        }
    }

    private func column(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(stat.value)
                .font(.scaled(14, weight: .semibold))
                .foregroundColor(stat.color)
                .moneyLine()
            Text(stat.label)
                .font(.scaled(10))
                .foregroundColor(.sMutedFG)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
