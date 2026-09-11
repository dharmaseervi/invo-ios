//
//  LabelSizePicker.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/18/25.
//


import SwiftUI

struct PrintLabelScreen: View {
    let item: ItemResponse
    @State private var selectedSize: LabelSize = .medium
    @State private var codeType: LabelCodeType = .qr
    @State private var quantity: Int = 1
    @State private var shareImage: UIImage?
    @State private var isPrinting = false
    @State private var printError: String?
    @State private var selectedPrinter: DiscoveredPrinter?
    @State private var autoCut = true

    @StateObject private var printerManager = LabelPrinterManager.shared
    @StateObject private var styleManager = LabelStyleManager.shared
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dismiss) private var dismiss

    private var previewImage: UIImage? {
        PrintImageBuilder.makeLabelImage(
            item: item,
            size: selectedSize,
            codeType: codeType,
            scale: displayScale,
            style: styleManager.style
        )
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        preview
                        PrinterPickerSection(selectedPrinter: $selectedPrinter, autoCut: $autoCut)
                        codeTypeSection
                        sizeSection
                        LabelStyleSection()
                        quantitySection
                    }
                    .padding(20)
                }

                actionBar
            }
        }
        .navigationTitle("Print label")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { shareImage.map { ShareImageWrapper(image: $0) } },
            set: { shareImage = $0?.image }
        )) { wrapper in
            ActivityView(activityItems: [wrapper.image])
        }
        .alert("Couldn't print", isPresented: Binding(
            get: { printError != nil },
            set: { if !$0 { printError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(printError ?? "")
        }
    }

    // MARK: - Preview
    private var preview: some View {
        VStack(spacing: 10) {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.sMuted)
                    .frame(height: 160)
                    .overlay(
                        Text("Preview unavailable")
                            .font(.system(size: 13))
                            .foregroundColor(.sMutedFG)
                    )
            }

            Text("\(selectedSize.subtitle) label · \(codeType.rawValue)")
                .font(.system(size: 12))
                .foregroundColor(.sMutedFG)

            Text(includedSummary)
                .font(.system(size: 11))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)

            if let warning = dataWarning {
                Text(warning)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.851, green: 0.588, blue: 0.082))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Spells out what actually lands on the label. A toggle can be switched on while the
    /// item has no SKU or cost price to print, and the label then comes out of the printer
    /// silently missing that line — this makes the reason visible before wasting a label.
    private var includedSummary: String {
        let style = styleManager.style
        var fields = ["Name"]

        if style.template == .compact {
            if style.showPrice { fields.append("Price") }
        } else {
            if style.showPrice { fields.append("Price") }
            if style.showID, !(item.sku ?? "").isEmpty { fields.append("SKU") }
            if style.showCostCode, (item.cost_price ?? 0) > 0 { fields.append("Cost code") }
        }

        return "Prints: " + fields.joined(separator: " · ")
    }

    private var dataWarning: String? {
        let style = styleManager.style

        if style.template == .compact, style.showID || style.showCostCode {
            return "Compact prints name and price only — switch template to include SKU or cost code."
        }

        var missing: [String] = []
        if style.showID, (item.sku ?? "").isEmpty { missing.append("no SKU") }
        if style.showCostCode, (item.cost_price ?? 0) <= 0 { missing.append("no cost price") }
        guard !missing.isEmpty else { return nil }

        return "This item has \(missing.joined(separator: " and ")) — that line won't print."
    }

    // MARK: - Code type
    private var codeTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Code type")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)

            HStack(spacing: 8) {
                ForEach(LabelCodeType.allCases, id: \.self) { type in
                    let isSelected = codeType == type
                    Button {
                        codeType = type
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type == .qr ? "qrcode" : "barcode")
                                .font(.system(size: 13, weight: .medium))
                            Text(type.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(isSelected ? .sAccentFG : .sForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.sAccent : Color.sCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color.sBorder, lineWidth: 0.5)
                        )
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    // MARK: - Size
    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Label size")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(LabelSize.allCases, id: \.self) { size in
                    let isSelected = selectedSize == size
                    Button {
                        selectedSize = size
                    } label: {
                        VStack(spacing: 3) {
                            Text(size.label)
                                .font(.system(size: 13, weight: .medium))
                            Text(size.subtitle)
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .sAccentFG.opacity(0.8) : .sMutedFG)
                        }
                        .foregroundColor(isSelected ? .sAccentFG : .sForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.sAccent : Color.sCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color.sBorder, lineWidth: 0.5)
                        )
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    // MARK: - Quantity
    private var quantitySection: some View {
        HStack {
            Text("Copies")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)

            Spacer()

            HStack(spacing: 0) {
                stepperButton(systemImage: "minus") {
                    if quantity > 1 { quantity -= 1 }
                }
                Text("\(quantity)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.sForeground)
                    .frame(minWidth: 36)
                stepperButton(systemImage: "plus") {
                    if quantity < 50 { quantity += 1 }
                }
            }
            .background(Color.sCard)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sBorder, lineWidth: 0.5))
            .cornerRadius(8)
        }
    }

    private func stepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.sForeground)
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        VStack(spacing: 10) {
            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            HStack(spacing: 10) {
                Button {
                    if let img = previewImage { shareImage = img }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.sForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(10)
                }

                Button {
                    Task { await printLabel() }
                } label: {
                    HStack(spacing: 6) {
                        if isPrinting {
                            ProgressView().tint(.sAccentFG)
                        } else {
                            Image(systemName: "printer.fill")
                            Text("Print\(quantity > 1 ? " ×\(quantity)" : "")")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.sAccentFG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sPrimary)
                    .cornerRadius(10)
                }
                .disabled(isPrinting)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
        .background(Color.sBackground)
    }

    private func printLabel() async {
        guard let image = previewImage else { return }
        let images = Array(repeating: image, count: quantity)

        isPrinting = true
        defer { isPrinting = false }

        do {
            try await printerManager.activeService.print(
                images: images,
                jobName: "Label-\(item.name)",
                printer: selectedPrinter,
                autoCut: autoCut
            )
        } catch {
            printError = error.localizedDescription
        }
    }
}

// MARK: - Share Helpers
private struct ShareImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
