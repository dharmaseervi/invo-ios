import Foundation

func json<T: Encodable>(_ value: T) throws -> [String: Any] {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any]
}

let oldJSON = #"{"id":1,"user_id":1,"company_id":1,"name":"Delivery","amount":25,"date":"2026-10-02T00:00:00Z"}"#
let oldExpense = try JSONDecoder().decode(Expense.self, from: Data(oldJSON.utf8))
precondition(oldExpense.paymentMethod == nil, "Older expense responses must remain readable")
let cashJSON = oldJSON.dropLast() + #", "payment_method":"Cash"}"#
let cashExpense = try JSONDecoder().decode(Expense.self, from: Data(cashJSON.utf8))
precondition(cashExpense.paymentMethod == "Cash")

let created = try json(ExpenseCreatePayload(companyId: 1, name: "Delivery", amount: 25,
                                            date: "2026-10-02", paymentMethod: "Cash"))
precondition(created["payment_method"] as? String == "Cash")
precondition(created["paymentMethod"] == nil)
let changed = try json(ExpenseUpdatePayload(paymentMethod: "UPI"))
precondition(changed["payment_method"] as? String == "UPI")
let cleared = try json(ExpenseUpdatePayload(paymentMethod: ""))
precondition(cleared["payment_method"] as? String == "", "Clearing must be sent explicitly")
let omitted = try json(ExpenseUpdatePayload())
precondition(omitted["payment_method"] == nil, "Unspecified methods must remain omitted")
print("PASS: expense decoding and create/change/clear payment-method payloads")
