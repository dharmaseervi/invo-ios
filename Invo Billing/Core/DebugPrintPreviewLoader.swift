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

/// Renders InvoiceDetailView with 100 locally-generated mock items — no login, no server.
/// Useful for auditing scroll performance and layout at scale.
struct DebugInvoice100View: View {
    @StateObject private var vm: InvoiceViewModel = {
        let v = InvoiceViewModel()
        v.previewMode = true
        let items = (1...100).map { i in
            InvoiceItemDetail(
                id: i,
                item_id: i,
                item_name: "Product \(i) – Sample Item Name",
                hsn_code: i % 3 == 0 ? "110100" : nil,
                qty: i,
                rate: Double(i) * 99.0,
                discount: i % 5 == 0 ? 10.0 : 0.0,
                tax_rate: 18.0,
                total: Double(i) * 99.0 * 1.18
            )
        }
        let subtotal = items.reduce(0) { $0 + $1.rate * Double($1.qty) }
        let tax      = items.reduce(0) { $0 + $1.rate * Double($1.qty) * ($1.tax_rate / 100) }
        v.invoiceDetail = InvoiceDetailResponse(
            id: 9999,
            invoice_number: "INV-2026-0001",
            status: .sent,
            invoice_date: "2026-10-01",
            due_date: "2026-10-31",
            subtotal: subtotal,
            tax: tax,
            discount: 0,
            total: subtotal + tax,
            paid_amount: 0,
            remaining_amount: subtotal + tax,
            is_overdue: false,
            days_overdue: 0,
            client: ClientSummary(id: 1, name: "Demo Client Pvt. Ltd."),
            items: items
        )
        return v
    }()

    var body: some View {
        InvoiceDetailView(invoiceID: 9999, vm: vm)
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
