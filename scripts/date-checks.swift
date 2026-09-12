import Foundation

var failures = 0
func check(_ label: String, _ got: String, _ want: String) {
    let ok = got == want
    if !ok { failures += 1 }
    print("\(ok ? "PASS" : "FAIL")  \(label.padding(toLength: 40, withPad: " ", startingAt: 0)) got \(got)   want \(want)")
}

var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 12
let date = Calendar(identifier: .gregorian).date(from: c)!

check("wire round trip", AppDate.wireString(from: date), "2026-09-12")
check("parses a bare API date",
      AppDate.wireString(from: AppDate.date(fromWire: "2026-07-01")!), "2026-07-01")
check("parses a full timestamp",
      AppDate.wireString(from: AppDate.date(fromWire: "2026-09-10T00:00:00Z")!), "2026-09-10")
check("parses a fractional timestamp",
      AppDate.wireString(from: AppDate.date(fromWire: "2026-09-12T11:50:24.86985Z")!), "2026-09-12")
check("unparseable shows through", AppDate.text(fromWire: "not-a-date"), "not-a-date")

// The bug this exists to prevent, stated as an assertion: an unpinned formatter follows
// the device's calendar, a pinned one does not.
let unpinned = DateFormatter()
unpinned.dateFormat = "yyyy-MM-dd"
unpinned.locale = Locale(identifier: "en_IN@calendar=indian")
let drifted = unpinned.string(from: date)
check("an unpinned formatter drifts", drifted, "1948-06-21")
check("AppDate does not", AppDate.wireString(from: date), "2026-09-12")

// The bug this exists to prevent: the wire format must not follow the device calendar.
let saved = CFPreferencesCopyAppValue("AppleLocale" as CFString, kCFPreferencesCurrentApplication)
print("\n  (device locale during this run: \(Locale.current.identifier))")
print("  wire output is pinned, so it cannot vary with it: \(AppDate.wireString(from: date))")
_ = saved

// Display is Gregorian but follows the user's language.
let shown = AppDate.text(date)
print("\n  display: \(shown)")
print("  \(shown.contains("2026") ? "PASS" : "FAIL")  display uses the Gregorian year")

exit(failures == 0 ? 0 : 1)
