//
//  SupplierStatementShareView.swift
//  Invo Billing
//
//  The statement a shop holds next to the one the supplier sends.
//

import PDFKit
import SwiftUI
import UIKit

struct SupplierStatementShareView: View {
    let supplier: Supplier

    @State private var pdfURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var requestID = UUID()
    @State private var period: Period = .thisFinancialYear
    @State private var customFrom = Date().addingTimeInterval(-30 * 86400)
    @State private var customTo = Date()

    enum Period: String, CaseIterable, Identifiable {
        case thisFinancialYear
        case last3Months
        case thisMonth
        case custom

        var id: String { rawValue }

        var label: String {
            switch self {
            case .thisFinancialYear: return "This year"
            case .last3Months: return "3 months"
            case .thisMonth: return "This month"
            case .custom: return "Pick dates"
            }
        }
    }

    private var range: (from: Date, to: Date) {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        switch period {
        case .thisFinancialYear:
            var start = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: now), month: 4, day: 1
            )) ?? now
            if start > now { start = calendar.date(byAdding: .year, value: -1, to: start) ?? start }
            return (start, now)
        case .last3Months:
            return (calendar.date(byAdding: .month, value: -3, to: now) ?? now, now)
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (start, now)
        case .custom:
            return (customFrom, customTo)
        }
    }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                periodControls

                Rectangle().fill(Color.sBorder).frame(height: 0.5)

                if isLoading {
                    Spacer()
                    ProgressView().tint(.sAccent)
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.scaled(26))
                            .foregroundColor(.sMutedFG)
                        Text(errorMessage)
                            .font(.scaled(13))
                            .foregroundColor(.sMutedFG)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        Button("Try again") { fetch() }
                            .font(.scaled(14, weight: .medium))
                            .foregroundColor(.sAccent)
                    }
                    Spacer()
                } else if let pdfURL {
                    SupplierStatementPDFView(url: pdfURL)
                }
            }
        }
        .navigationTitle(supplier.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label("Send statement", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button { printStatement() } label: {
                        Label("Print", systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(pdfURL == nil ? .sMutedFG : .sAccent)
                }
                .disabled(pdfURL == nil)
            }
        }
        .task { fetch() }
        .onChange(of: period) { _ in fetch() }
    }

    private var periodControls: some View {
        VStack(spacing: 10) {
            Picker("Period", selection: $period) {
                ForEach(Period.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if period == .custom {
                HStack(spacing: 12) {
                    DatePicker("", selection: $customFrom, displayedComponents: .date)
                        .labelsHidden()
                    Text("to")
                        .font(.scaled(12))
                        .foregroundColor(.sMutedFG)
                    DatePicker("", selection: $customTo, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    Button("Apply") { fetch() }
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sAccent)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func fetch() {
        let request = UUID()
        requestID = request
        pdfURL = nil
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select a company first."
            isLoading = false
            return
        }

        let selectedRange = range
        guard selectedRange.from <= selectedRange.to else {
            errorMessage = "The start date must be on or before the end date."
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let start = dateFormatter.string(from: selectedRange.from)
        let end   = dateFormatter.string(from: selectedRange.to)

        Task {
            do {
                let pdfData = try await PurchasesService().supplierStatementPDF(
                    companyID: companyID,
                    supplierID: supplier.id,
                    start: start,
                    end: end
                )
                guard requestID == request else { return }
                guard PDFKit.PDFDocument(data: pdfData) != nil else {
                    throw URLError(.cannotDecodeContentData)
                }
                // Write to a temp file so PDFView and the share sheet can both use a URL.
                let dir = FileManager.default.temporaryDirectory
                let file = dir.appendingPathComponent("SupplierStatement_\(supplier.id)_\(request.uuidString).pdf")
                try pdfData.write(to: file)
                await MainActor.run {
                    guard requestID == request else { return }
                    pdfURL = file
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    guard requestID == request else { return }
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func printStatement() {
        guard let pdfURL else { return }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = "SupplierStatement_\(supplier.name)"
        info.outputType = .general
        controller.printInfo = info
        controller.printingItem = pdfURL
        controller.present(animated: true)
    }
}

private struct SupplierStatementPDFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground
        view.document = PDFKit.PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFKit.PDFDocument(url: url)
        }
    }
}
