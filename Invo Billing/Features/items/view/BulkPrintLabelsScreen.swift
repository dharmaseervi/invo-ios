import SwiftUI

/// Prints labels for several items in one batch — same size/code-type/printer settings
/// applied to all of them, with a per-item copy count.
struct BulkPrintLabelsScreen: View {
    let items: [ItemResponse]

    @State private var selectedSize: LabelSize = .medium
    @State private var codeType: LabelCodeType = .qr
    @State private var quantities: [Int: Int] = [:] // item.id -> copies
    @State private var selectedPrinter: DiscoveredPrinter?
    @State private var autoCut = true
    @State private var isPrinting = false
    @State private var printError: String?
    @State private var printedSuccessfully = false

    @Environment(\.displayScale) private var displayScale
    @Environment(\.dismiss) private var dismiss
    @StateObject private var printerManager = LabelPrinterManager.shared
    @StateObject private var styleManager = LabelStyleManager.shared

    private var totalLabelCount: Int {
        items.reduce(0) { $0 + (quantities[$1.id] ?? 1) }
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        itemsSection
                        PrinterPickerSection(selectedPrinter: $selectedPrinter, autoCut: $autoCut)
                        codeTypeSection
                        sizeSection
                        LabelStyleSection()
                    }
                    .padding(AppSpacing.card)
                }

                actionBar
            }
        }
        .navigationTitle("Print \(items.count) labels")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for item in items where quantities[item.id] == nil {
                quantities[item.id] = 1
            }
        }
        .alert("Couldn't print", isPresented: Binding(
            get: { printError != nil },
            set: { if !$0 { printError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(printError ?? "")
        }
        .alert("Sent to printer", isPresented: $printedSuccessfully) {
            Button("Done") { dismiss() }
        } message: {
            Text("\(totalLabelCount) label\(totalLabelCount == 1 ? "" : "s") sent.")
        }
    }

    // MARK: - Items
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    AdaptiveFormRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.sForeground)

                            Text(Money.text(item.price)).moneyLine()
                                .font(.caption)
                                .foregroundColor(.sMutedFG)
                        }

                        Spacer()

                        Stepper(value: Binding(
                            get: { quantities[item.id] ?? 1 },
                            set: { quantities[item.id] = $0 }
                        ), in: 1...50) {
                            Text("\(quantities[item.id] ?? 1) copies").font(.body)
                        }
                        .accessibilityLabel("Label copies for \(item.name)")
                        .accessibilityValue("\(quantities[item.id] ?? 1)")
                    }
                    .padding(12)
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Code type
    private var codeTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Code type")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)

            HStack(spacing: 8) {
                ForEach(LabelCodeType.allCases, id: \.self) { type in
                    let isSelected = codeType == type
                    Button {
                        codeType = type
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type == .qr ? "qrcode" : "barcode")
                                .font(.subheadline.weight(.medium))
                            Text(type.rawValue)
                                .font(.subheadline.weight(.medium))
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
                .font(.subheadline.weight(.medium))
                .foregroundColor(.sMutedFG)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(LabelSize.allCases, id: \.self) { size in
                    let isSelected = selectedSize == size
                    Button {
                        selectedSize = size
                    } label: {
                        VStack(spacing: 3) {
                            Text(size.label)
                                .font(.subheadline.weight(.medium))
                            Text(size.subtitle)
                                .font(.caption)
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

    // MARK: - Action Bar
    private var actionBar: some View {
        VStack(spacing: 10) {
            Rectangle().fill(Color.sBorder).frame(height: 0.5)

            Button {
                Task { await printAll() }
            } label: {
                HStack(spacing: 8) {
                    if isPrinting {
                        ProgressView().tint(.sAccentFG)
                    } else {
                        Image(systemName: "printer.fill")
                        Text("Print \(totalLabelCount) label\(totalLabelCount == 1 ? "" : "s")")
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.sAccentFG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.sPrimary)
                .cornerRadius(10)
            }
            .disabled(isPrinting)
            .padding(.horizontal, AppSpacing.page)
        }
        .padding(.bottom, 12)
        .background(Color.sBackground)
    }

    private func printAll() async {
        isPrinting = true
        defer { isPrinting = false }

        var allImages: [UIImage] = []
        for item in items {
            guard let image = PrintImageBuilder.makeLabelImage(
                item: item, size: selectedSize, codeType: codeType, scale: displayScale,
                style: styleManager.style
            ) else { continue }
            let copies = quantities[item.id] ?? 1
            allImages.append(contentsOf: Array(repeating: image, count: copies))
        }

        guard !allImages.isEmpty else {
            printError = "Nothing to print"
            return
        }

        do {
            try await printerManager.activeService.print(
                images: allImages,
                jobName: "Bulk labels (\(items.count) items)",
                printer: selectedPrinter,
                autoCut: autoCut
            )
            printedSuccessfully = true
        } catch {
            printError = error.localizedDescription
        }
    }
}
