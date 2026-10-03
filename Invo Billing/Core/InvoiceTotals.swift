//
//  InvoiceTotals.swift
//  Invo Billing
//
//  Invoice arithmetic, matching the server exactly.
//
//  The screens used to add up their own way: subtotal + tax - discount. The server
//  applies an invoice-level discount BEFORE tax, apportioned across the lines, because
//  a discount shown on the invoice reduces the transaction value (CGST s.15(3)) — so
//  tax is due on the discounted amount. With any invoice discount the preview therefore
//  showed one total and the saved invoice had another, and the figure the customer was
//  quoted was not the figure on their bill.
//
//  Everything here is in whole paise. Float arithmetic on money drifts, and these
//  figures are compared against the server's decimal maths down to the paisa.
//

import Foundation

/// One line's amounts, rounded the way the server rounds them.
struct TotalsLine: Equatable {
    /// The line discount actually applied, capped at the line value.
    var discount: Double
    /// Taxable value after the line discount and this line's share of the invoice discount.
    var net: Double
    var tax: Double
    /// net + tax, which is what the server stores on the line.
    var total: Double
}

/// The header figures. `subtotal` is the taxable value BEFORE the invoice discount, so
/// an invoice can print Subtotal, Discount, tax and Total and have them reconcile:
/// subtotal - discount + tax == total.
struct InvoiceTotals: Equatable {
    var lines: [TotalsLine] = []
    var subtotal: Double = 0
    var discount: Double = 0
    var tax: Double = 0
    var total: Double = 0
}

enum Totals {
    /// What one line contributes, before any invoice-level discount.
    struct Line {
        var qty: Int
        var rate: Double
        var discount: Double
        var taxRate: Double

        init(qty: Int, rate: Double, discount: Double = 0, taxRate: Double) {
            self.qty = qty
            self.rate = rate
            self.discount = discount
            self.taxRate = taxRate
        }
    }

    /// The same arithmetic as the server's computeInvoiceTotals, in the same order.
    static func compute(lines input: [Line], invoiceDiscount: Double) -> InvoiceTotals {
        var out = InvoiceTotals()
        var nets: [Int] = []
        var taxes: [Int] = []
        var subtotalPaise = 0

        for line in input {
            let qty = max(line.qty, 0)
            let base = paise(line.rate) * qty
            // Capped at the line value: a discount bigger than the line would otherwise
            // make the line, and the invoice, owe less than nothing.
            let lineDiscount = min(paise(max(line.discount, 0)), base)
            let net = base - lineDiscount
            let tax = tax(onPaise: net, rate: line.taxRate)

            out.lines.append(TotalsLine(
                discount: rupees(lineDiscount), net: rupees(net),
                tax: rupees(tax), total: rupees(net + tax)
            ))
            nets.append(net)
            taxes.append(tax)
            subtotalPaise += net
        }

        let discountPaise = min(paise(max(invoiceDiscount, 0)), subtotalPaise)

        if discountPaise > 0 {
            let shares = apportion(discountPaise, weights: nets)
            for i in nets.indices {
                let taxable = nets[i] - shares[i]
                let tax = tax(onPaise: taxable, rate: input[i].taxRate)
                nets[i] = taxable
                taxes[i] = tax
                out.lines[i].net = rupees(taxable)
                out.lines[i].tax = rupees(tax)
                out.lines[i].total = rupees(taxable + tax)
            }
        }

        let totalTax = taxes.reduce(0, +)
        out.subtotal = rupees(subtotalPaise)
        out.discount = rupees(discountPaise)
        out.tax = rupees(totalTax)
        out.total = rupees(subtotalPaise - discountPaise + totalTax)
        return out
    }

    // MARK: - Paise arithmetic

    /// Rupees to whole paise, rounded half away from zero — the same rounding the
    /// server's decimal type uses.
    private static func paise(_ amount: Double) -> Int {
        guard amount.isFinite else { return 0 }
        return Int((amount * 100).rounded())
    }

    private static func rupees(_ paise: Int) -> Double { Double(paise) / 100 }

    /// Tax on a taxable amount, rounded to the paisa.
    private static func tax(onPaise net: Int, rate: Double) -> Int {
        guard rate.isFinite, rate > 0 else { return 0 }
        return Int((Double(net) * rate / 100).rounded())
    }

    /// Splits `total` across `weights` so the parts add up to exactly `total`.
    ///
    /// Each share is truncated down first, then the paise left over go to the lines that
    /// lost the most to truncation — largest remainder first, earlier line first on a
    /// tie. Without that last step the shares would add up to a paisa or two less than
    /// the discount, and the invoice would not reconcile.
    private static func apportion(_ total: Int, weights: [Int]) -> [Int] {
        var shares = [Int](repeating: 0, count: weights.count)
        let sum = weights.reduce(0, +)
        guard total != 0, sum > 0 else { return shares }

        var remainders: [(index: Int, frac: Int)] = []
        var allocated = 0
        for (i, w) in weights.enumerated() {
            // Full width, because total * w overflows on real figures: both are in
            // paise, so a 3-crore discount against a 4-crore line multiplies out to
            // 1.2e19 — past Int64, which in Swift is a crash rather than a wrong
            // number. multipliedFullWidth keeps all 128 bits and dividingFullWidth
            // brings it back down; the quotient cannot overflow because w <= sum, so
            // the share is never more than the total being split.
            let wide = total.multipliedFullWidth(by: w)
            let (share, frac) = sum.dividingFullWidth(wide)
            shares[i] = share
            allocated += share
            remainders.append((i, frac))
        }

        var left = total - allocated
        remainders.sort { $0.frac != $1.frac ? $0.frac > $1.frac : $0.index < $1.index }
        var k = 0
        while left > 0 && !remainders.isEmpty {
            shares[remainders[k % remainders.count].index] += 1
            left -= 1
            k += 1
        }
        return shares
    }
}
