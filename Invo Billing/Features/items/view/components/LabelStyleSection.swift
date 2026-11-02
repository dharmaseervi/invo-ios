import SwiftUI

/// Lets the user pick a label template and tune its text — shared between single-item
/// and bulk label printing. Settings persist across print jobs. Title/body text size are
/// each a multiplier on top of that label size's own base font sizes, so they always stay
/// proportional no matter which of the 6 size templates is active.
struct LabelStyleSection: View {
    @ObservedObject var styleManager = LabelStyleManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            templateSection

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Text & fields")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.sMutedFG)
                    Spacer()
                    Button("Reset") {
                        styleManager.resetToDefault()
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.sAccent)
                }

                VStack(spacing: 12) {
                    sliderRow(label: "Title size (top)", value: $styleManager.style.titleScale)
                    sliderRow(label: "Body size (bottom)", value: $styleManager.style.bodyScale)

                    Rectangle().fill(Color.sBorder).frame(height: 0.5)

                    alignmentRow

                    Rectangle().fill(Color.sBorder).frame(height: 0.5)

                    Toggle(isOn: $styleManager.style.showPrice) {
                        Text("Show price").font(.subheadline).foregroundStyle(Color.sForeground)
                    }
                    .tint(Color.sAccent)
                    Toggle(isOn: $styleManager.style.showID) {
                        Text("Show SKU").font(.subheadline).foregroundStyle(Color.sForeground)
                    }
                    .tint(Color.sAccent)
                    Toggle(isOn: $styleManager.style.showCostCode) {
                        Text("Show cost code").font(.subheadline).foregroundStyle(Color.sForeground)
                    }
                    .tint(Color.sAccent)
                }
                .padding(12)
                .background(Color.sCard)
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5) }
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Template picker
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Label template")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.sMutedFG)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(LabelTemplate.allCases, id: \.self) { template in
                    let isSelected = styleManager.style.template == template
                    Button {
                        styleManager.style.template = template
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: template.icon)
                                .font(.subheadline.weight(.medium))
                            Text(template.label)
                                .font(.subheadline.weight(.semibold))
                            Text(template.subtitle)
                                .font(.caption)
                                .foregroundStyle(isSelected ? Color.sAccentFG.opacity(0.8) : Color.sMutedFG)
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? Color.sAccentFG : Color.sForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(isSelected ? Color.sAccent : Color.sCard)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color.sBorder, lineWidth: 0.5)
                        }
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var alignmentRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Text alignment")
                .font(.subheadline)
                .foregroundStyle(Color.sForeground)

            HStack(spacing: 8) {
                ForEach(LabelTextAlignment.allCases, id: \.self) { alignment in
                    let isSelected = styleManager.style.textAlignment == alignment
                    Button {
                        styleManager.style.textAlignment = alignment
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: alignment.icon)
                            Text(alignment.label)
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(isSelected ? Color.sAccentFG : Color.sForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.sAccent : Color.sBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.clear : Color.sBorder, lineWidth: 0.5)
                        }
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func sliderRow(label: String, value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.sForeground)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.footnote)
                    .foregroundStyle(Color.sMutedFG)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = CGFloat($0) }
                ),
                in: Double(LabelStyle.scaleRange.lowerBound)...Double(LabelStyle.scaleRange.upperBound),
                step: 0.05
            )
            .tint(Color.sAccent)
        }
    }
}
