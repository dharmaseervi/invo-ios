//
//  StatementShareView.swift
//  Invo Billing
//
//  The statement a shop sends a customer who says they have paid everything.
//

import PDFKit
import SwiftUI
import UIKit

struct StatementShareView: View {
    let clientID: Int
    let clientName: String

    @Environment(\.dismiss) private var dismiss

    @State private var pdfURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var period: Period = .thisFinancialYear
    @State private var customFrom = Date().addingTimeInterval(-30 * 86400)
    @State private var customTo = Date()

    /// The periods a shopkeeper actually asks for. "This year" means the Indian
    /// financial year — April to March — not January to December.
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
                    StatementPDFView(url: pdfURL)
                }
            }
        }
        .navigationTitle(clientName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        share()
                    } label: {
                        Label("Send statement", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        print()
                    } label: {
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
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            errorMessage = "Select a company first."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let url = try await StatementService().statementPDF(
                    companyID: companyID,
                    clientID: clientID,
                    clientName: clientName,
                    from: range.from,
                    to: range.to
                )
                await MainActor.run {
                    pdfURL = url
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // The server's own sentence where there is one: "That customer
                    // isn't one of this company's" is an answer, not a failure.
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func share() {
        guard let pdfURL else { return }
        let activity = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        // iPad presents this from a popover and crashes without a source to point at.
        if let popover = activity.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(
                x: root.view.bounds.midX, y: root.view.bounds.maxY - 60, width: 0, height: 0
            )
        }
        root.present(activity, animated: true)
    }

    private func print() {
        guard let pdfURL else { return }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = "Statement_\(clientName)"
        info.outputType = .general
        controller.printInfo = info
        controller.printingItem = pdfURL
        controller.present(animated: true)
    }
}

/// The statement itself, shown before it is sent. Nobody should have to send a document
/// to a customer they have not seen.
private struct StatementPDFView: UIViewRepresentable {
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
        // Reloaded when the period changes and a new file arrives.
        if view.document?.documentURL != url {
            view.document = PDFKit.PDFDocument(url: url)
        }
    }
}
