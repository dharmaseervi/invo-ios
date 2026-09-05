import SwiftUI
import PDFKit

/// Shows the real, server-generated estimate PDF (same document "Download PDF" produces)
/// so Print/Share always reflect the actual estimate — not a mocked-up preview.
struct EstimatePrintView: View {
    let estimateDetail: EstimateDetailResponse
    @Environment(\.dismiss) var dismiss

    @State private var pdfURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTemplate = InvoiceTemplatePreference.load()
    @State private var showTemplatePicker = false

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.sForeground)
                    }
                    Spacer()
                    Text("Print estimate")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.sForeground)
                    Spacer()
                    Menu {
                        Button(action: printEstimate) {
                            Label("Print", systemImage: "printer")
                        }
                        Button(action: sharePDF) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(pdfURL == nil ? .sMutedFG : .sAccent)
                    }
                    .disabled(pdfURL == nil)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                // MARK: - Template selector
                Button {
                    showTemplatePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 12))
                        Text("Template: \(selectedTemplate.title)")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.sForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.sCard)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sBorder, lineWidth: 0.5))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // MARK: - PDF Preview
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.sAccent)
                        Text("Preparing document...")
                            .font(.system(size: 13))
                            .foregroundColor(.sMutedFG)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundColor(.sDestructive)
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                        Button("Try again") { fetchPDF() }
                            .font(.system(size: 13, weight: .medium))
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
                    Button(action: printEstimate) {
                        HStack(spacing: 8) {
                            Image(systemName: "printer.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Print")
                                .font(.system(size: 15, weight: .semibold))
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
                                .font(.system(size: 13, weight: .semibold))
                            Text("Download / Share")
                                .font(.system(size: 14, weight: .medium))
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
                let url = try await EstimateService().downloadEstimatePDF(
                    estimateID: estimateDetail.id,
                    template: selectedTemplate
                )
                await MainActor.run {
                    self.pdfURL = url
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load the estimate PDF"
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Actions

    private func printEstimate() {
        guard let pdfURL else { return }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Estimate_\(estimateDetail.estimate_number)"
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
