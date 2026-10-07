import SwiftUI
import PDFKit

/// Shows the real, server-generated invoice PDF (same document "Download PDF" produces)
/// so Print/Share always reflect the actual invoice — not a mocked-up preview.
struct InvoicePrintView: View {
    let invoiceDetail: InvoiceDetailResponse
    @Environment(\.dismiss) var dismiss

    @State private var pdfURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedCopy = "original"
    @State private var selectedTemplate = InvoiceTemplatePreference.load()
    @State private var showTemplatePicker = false

    private let copies: [(label: String, value: String)] = [
        ("Original", "original"),
        ("Duplicate", "duplicate"),
        ("Buyer copy", "buyer"),
    ]

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.scaled(14, weight: .semibold))
                            Text("Back")
                                .font(.scaled(14))
                        }
                        .foregroundColor(.sForeground)
                    }
                    Spacer()
                    Text("Print invoice")
                        .font(.scaled(15, weight: .semibold))
                        .foregroundColor(.sForeground)
                    Spacer()
                    Menu {
                        Button(action: printInvoice) {
                            Label("Print", systemImage: "printer")
                        }
                        .disabled(pdfURL == nil)
                        Button(action: sharePDF) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .disabled(pdfURL == nil)
                        Divider()
                        Button(action: printTestPage) {
                            Label("Print test page", systemImage: "printer.dotmatrix")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.scaled(14, weight: .semibold))
                            .foregroundColor(.sAccent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                // MARK: - Copy selector
                Picker("Copy", selection: $selectedCopy) {
                    ForEach(copies, id: \.value) { copy in
                        Text(copy.label).tag(copy.value)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .onChange(of: selectedCopy) { _ in
                    fetchPDF()
                }

                // MARK: - Template selector
                Button {
                    showTemplatePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette")
                            .font(.scaled(12))
                        Text("Template: \(selectedTemplate.title)")
                            .font(.scaled(13, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.scaled(11, weight: .semibold))
                    }
                    .foregroundColor(.sForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // MARK: - PDF Preview
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.sAccent)
                        Text("Preparing document...")
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.scaled(28))
                            .foregroundColor(.sDestructive)
                        Text(errorMessage)
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                        Button("Try again") { fetchPDF() }
                            .font(.scaled(13, weight: .medium))
                            .foregroundColor(.sAccent)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pdfURL {
                    PDFKitView(url: pdfURL)
                        .padding(.top, 12)
                }

                // MARK: - Action Buttons
                VStack(spacing: 10) {
                    Button(action: printInvoice) {
                        HStack(spacing: 8) {
                            Image(systemName: "printer.fill")
                                .font(.scaled(13, weight: .semibold))
                            Text("Print")
                                .font(.scaled(15, weight: .semibold))
                        }
                        .foregroundColor(.sAccentFG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(pdfURL == nil ? Color.sPrimary.opacity(0.4) : Color.sPrimary)
                        .cornerRadius(10)
                    }
                    .disabled(pdfURL == nil)

                    Button(action: sharePDF) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.scaled(13, weight: .semibold))
                            Text("Download / Share")
                                .font(.scaled(14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.sForeground)
                        .background(Color.sCard)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sBorder, lineWidth: 0.5))
                        .cornerRadius(10)
                    }
                    .disabled(pdfURL == nil)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.sBackground)
            }
        }
        .navigationBarHidden(true)
        .onAppear { fetchPDF() }
        .sheet(isPresented: $showTemplatePicker) {
            InvoiceTemplatePickerSheet(selected: $selectedTemplate) { template in
                selectedTemplate = template
                InvoiceTemplatePreference.save(template)
                showTemplatePicker = false
                fetchPDF()
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Data

    private func fetchPDF() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let url = try await InvoicePDFService().downloadInvoicePDF(
                    invoiceID: invoiceDetail.id,
                    copy: selectedCopy,
                    template: selectedTemplate
                )
                await MainActor.run {
                    self.pdfURL = url
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load the invoice PDF"
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Actions

    private func printInvoice() {
        guard let pdfURL else { return }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Invoice_\(invoiceDetail.invoice_number)"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printingItem = pdfURL
        printController.present(animated: true)
    }

    private func sharePDF() {
        guard let pdfURL else { return }
        let activityVC = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.windows.first?.rootViewController?.present(activityVC, animated: true)
        }
    }

    private func printTestPage() {
        guard let url = generateTestPDF() else { return }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Invo Billing – Test Page"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printingItem = url
        printController.present(animated: true)
    }

    private func generateTestPDF() -> URL? {
        let pageSize = CGSize(width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let dateStr = df.string(from: Date())

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let margin: CGFloat = 60
            var y: CGFloat = margin

            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 38),
                .foregroundColor: UIColor.systemGray
            ]
            ("TEST PRINT" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 56

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.systemGray2
            ]
            ("Printer connection test · Invo Billing" as NSString)
                .draw(at: CGPoint(x: margin, y: y), withAttributes: subAttrs)
            y += 30

            UIColor.systemGray4.setFill()
            UIRectFill(CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 1))
            y += 24

            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.systemGray
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]

            let rows: [(String, String)] = [
                ("Invoice number", "TEST-001"),
                ("Date", dateStr),
                ("Client", "Test Client"),
                ("Item", "Sample Product × 1"),
                ("Rate", "₹1,000.00"),
                ("Tax (18% GST)", "₹180.00"),
                ("Total", "₹1,180.00"),
            ]
            for (label, value) in rows {
                (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                (value as NSString).draw(at: CGPoint(x: 240, y: y), withAttributes: valueAttrs)
                y += 26
            }

            y += 16
            UIColor.systemGray4.setFill()
            UIRectFill(CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 1))
            y += 22

            let noteAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 11),
                .foregroundColor: UIColor.systemGray2
            ]
            ("If you can read this clearly, your printer is connected correctly." as NSString)
                .draw(at: CGPoint(x: margin, y: y), withAttributes: noteAttrs)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("invo_test_print.pdf")
        try? data.write(to: url)
        return url
    }
}

// MARK: - PDFKit Wrapper
private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFKit.PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFKit.PDFDocument(url: url)
        }
    }
}

// MARK: - Template Preference (remembers the last chosen style)
enum InvoiceTemplatePreference {
    private static let key = "invoice_template_preference"

    static func load() -> InvoiceTemplate {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let template = InvoiceTemplate(rawValue: raw)
        else { return .classic }
        return template
    }

    static func save(_ template: InvoiceTemplate) {
        UserDefaults.standard.set(template.rawValue, forKey: key)
    }
}

// MARK: - Template Picker Sheet
struct InvoiceTemplatePickerSheet: View {
    @Binding var selected: InvoiceTemplate
    let onSelect: (InvoiceTemplate) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sBackground.ignoresSafeArea()

                VStack(spacing: 10) {
                    ForEach(InvoiceTemplate.allCases) { template in
                        Button {
                            onSelect(template)
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.title)
                                        .font(.scaled(15, weight: .semibold))
                                        .foregroundColor(.sForeground)
                                    Text(template.subtitle)
                                        .font(.scaled(12))
                                        .foregroundColor(.sMutedFG)
                                }
                                Spacer()
                                if selected == template {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.scaled(18))
                                        .foregroundColor(.sAccent)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.scaled(18))
                                        .foregroundColor(.sBorder)
                                }
                            }
                            .padding(16)
                            .background(Color.sCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selected == template ? Color.sAccent.opacity(0.4) : Color.sBorder, lineWidth: 0.5)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Choose a style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
