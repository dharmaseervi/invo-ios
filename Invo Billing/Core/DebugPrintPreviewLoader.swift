//
//  DebugPrintPreviewLoader.swift
//  Invo Billing
//

#if DEBUG
import SwiftUI

/// Opens the invoice print preview directly, for the large-text audit.
///
/// The preview is normally three taps deep — list, detail, Print — and the simulator
/// tooling on this machine cannot tap. Reaching it through nested navigation did not
/// work either: two `navigationDestination(isPresented:)` in one stack do not both
/// fire. So this loads the first invoice itself and presents the real
/// ``InvoicePrintView``, one level down from More, where the existing debug route
/// already works.
///
/// Debug only, and compiled out of Release along with the rest of the `-startScreen`
/// plumbing.
struct DebugPrintPreviewLoader: View {
    @StateObject private var vm = InvoiceViewModel()
    @State private var detail: InvoiceDetailResponse?

    var body: some View {
        Group {
            if let detail {
                InvoicePrintView(invoiceDetail: detail)
            } else {
                ProgressView("Loading an invoice…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await vm.fetchInvoices()
            guard let first = vm.invoices.first else { return }
            await vm.fetchInvoiceDetail(invoiceID: first.id)
            detail = vm.invoiceDetail
        }
    }
}

/// The full-screen QuickLook viewer, which puts "Back" plus three icon buttons in one
/// row — the layout most likely to overflow at an accessibility text size.
struct DebugPDFLookLoader: View {
    @StateObject private var vm = InvoiceViewModel()

    var body: some View {
        Group {
            if let url = vm.pdfURL {
                PDFLookView(pdfURL: url)
            } else {
                ProgressView("Loading a PDF…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await vm.fetchInvoices()
            guard let first = vm.invoices.first else { return }
            await vm.generateInvoicePDFFromServer(invoiceID: first.id, copy: "original")
        }
    }
}
#endif
