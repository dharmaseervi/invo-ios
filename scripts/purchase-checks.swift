import Foundation

for invalid in ["abc", "1,000", "-1", "nan", "inf", "1.001", "10000000000"] {
    precondition(PurchaseAmountInput.parse(invalid) == nil, "Invalid amount accepted: \(invalid)")
}
precondition(PurchaseAmountInput.parse("") == nil)
precondition(PurchaseAmountInput.parse("", emptyAsZero: true) == 0)
precondition(PurchaseAmountInput.parse(" 1250.50 ") == 1250.50)

let simple = NewPurchaseBillRequest(supplier_id: 1, bill_number: "AMT-01",
    bill_date: "2026-10-06", items: [], paid_amount: 250, paid_method: "UPI", bill_amount: 1250)
let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(simple)) as! [String: Any]
precondition(json["bill_amount"] as? Double == 1250)
precondition((json["items"] as? [Any])?.isEmpty == true)
precondition(json["paid_amount"] as? Double == 250)
let stock = NewPurchaseBillRequest(supplier_id: 1, bill_number: "STOCK-01",
    items: [PurchaseLineRequest(item_id: 1, qty: 2, rate: 100, tax_rate: 18)], paid_amount: 0)
let stockJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(stock)) as! [String: Any]
precondition(stockJSON["bill_amount"] == nil, "Item-based requests must not send a manual total")
let oldBill = #"{"id":1,"supplier_id":1,"supplier_name":"Supplier","bill_number":"B1","bill_date":"2026-10-06","due_date":"","subtotal":100,"tax":0,"total":100,"paid_amount":0,"remaining_amount":100,"status":"unpaid"}"#
let decodedOldBill = try JSONDecoder().decode(PurchaseBill.self, from: Data(oldBill.utf8))
precondition(!decodedOldBill.isAmountOnly)
let simpleBill = String(oldBill.dropLast()) + #", "amount_only":true}"#
let decodedSimpleBill = try JSONDecoder().decode(PurchaseBill.self, from: Data(simpleBill.utf8))
precondition(decodedSimpleBill.isAmountOnly)
print("PASS: purchase input validation, amount-only and stock payloads, backward-compatible bill decoding")
