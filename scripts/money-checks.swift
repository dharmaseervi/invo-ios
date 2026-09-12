import Foundation

func check(_ label: String, _ got: String, _ want: String) {
    print("\(got == want ? "PASS" : "FAIL")  \(label.padding(toLength: 34, withPad: " ", startingAt: 0)) got \(got)   want \(want)")
}

// Indian grouping: 2,2,3 not 3,3,3
check("lakh grouping",        Money.text(548632),    "₹5,48,632.00")
check("crore grouping",       Money.text(14365150),  "₹1,43,65,150.00")
check("thousands",            Money.text(5310),      "₹5,310.00")
check("under a thousand",     Money.text(566.4),     "₹566.40")
check("zero",                 Money.text(0),         "₹0.00")
check("negative before symbol", Money.text(-380),    "−₹380.00")
check("rounds to paisa",      Money.text(1234.567),  "₹1,234.57")

check("compact lakhs",        Money.compact(548632), "₹5.5L")
check("compact whole lakhs",  Money.compact(500000), "₹5L")
check("compact thousands",    Money.compact(13514),  "₹13.5K")
check("compact small",        Money.compact(950),    "₹950.00")
check("compact negative",     Money.compact(-13514), "−₹13.5K")

// Editable must round-trip through Double, or the field breaks on edit.
check("editable plain",       Money.editable(548632), "548632.00")
check("editable negative",    Money.editable(-380),   "-380.00")
let roundTrip = Double(Money.editable(548632.49)) ?? -1
print("\(roundTrip == 548632.49 ? "PASS" : "FAIL")  editable round-trips through Double   got \(roundTrip)")

// Guard against non-finite values reaching the UI.
check("infinity is safe",     Money.text(.infinity),  "₹0.00")
check("nan is safe",          Money.text(.nan),       "₹0.00")
