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
                    .padding(20)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.sMutedFG)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.sForeground)
                                .lineLimit(1)
                            Text("₹\(String(format: "%.2f", item.price))")
                                .font(.system(size: 11))
                                .foregroundColor(.sMutedFG)
                        }

                        Spacer()

                        HStack(spacing: 0) {
                            quantityButton(systemImage: "minus") {
                                let current = quantities[item.id] ?? 1
                                if current > 1 { quantities[item.id] = current - 1 }
                            }
                            Text("\(quantities[item.id] ?? 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.sForeground)
                                .frame(minWidth: 28)
                            quantityButton(systemImage: "plus") {
                                let current = quantities[item.id] ?? 1
                                if current < 50 { quantities[item.id] = current + 1 }
                            }
                        }
                        .background(Color.sCard)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.sBorder, lineWidth: 0.5))
                        .cornerRadius(6)
                    }
                    .padding(12)
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(10)
                }
            }
        }
    }

    private func quantityButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.sForeground)
                .frame(width: 26, height: 26)
        }
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.sAccentFG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.sPrimary)
                .cornerRadius(10)
            }
            .disabled(isPrinting)
            .padding(.horizontal, 20)
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
