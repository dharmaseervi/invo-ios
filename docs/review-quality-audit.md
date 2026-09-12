# Quality audit — 12 September 2026

App Review rejected the app under the quality bar: *"free of inconsistencies,
placeholder content, or elements that appear unintentional, unfinished, or
unrefined"*, with no resubmission allowed on that record.

This is a walk through the running app on an iPhone 17 Pro Max looking for exactly
those things. The code itself is sound — 133 files, no placeholder strings, no force
unwraps, no `fatalError`, empty and loading states throughout. Everything below is
about finish.

Ordered by how much a reviewer would notice.

---

## 1. Money is formatted three different ways  ← highest impact

The same rupee value renders differently depending on the screen:

| Screen | Renders as |
|---|---|
| Dashboard | `₹14K` |
| Invoice list, Estimates | `₹5310` |
| GST report, Stock report | `₹5310.00` |
| Stock report totals | `₹548632.00` |

**No shared currency formatter exists.** There are 50 hand-written
`String(format: "%.2f")` call sites and one local `formattedAmount` on the dashboard
that abbreviates to K/L.

Worse, **nothing uses Indian digit grouping**. `₹548632.00` should read `₹5,48,632.00`.
The stock report is a full screen of six-figure sums with no separators at all, which
is the single most "unfinished" thing in the app — and this is billing software, where
the numbers *are* the product.

**Fix:** one `Money.format(_:)` helper using `NumberFormatter` with `en_IN`, then
replace the call sites. Decide one rule — group digits, always two decimals, no K/L
abbreviation outside the dashboard headline — and apply it everywhere.

## 2. Dates are formatted three different ways

- `Sep 12, 2026` — US style, on the new-invoice form
- `11 Sept 2026` — on invoice lists
- `2026-09-12` — raw ISO, in "as of 2026-09-12" on the stock report

**Fix:** one shared date formatter, locale-aware, the same everywhere. Never show ISO
to a user.

## 3. New invoice: two bottom bars stacked

The sticky "Total / Create invoice" bar sits directly beneath the floating tab bar,
and they crowd each other. Unlike a scrolling list — where content passing under the
translucent tab bar is normal iOS 26 behaviour — this bar is fixed and can never be
moved clear.

**Fix:** present invoice creation modally (`.sheet` or `.fullScreenCover`) so the tab
bar is not there at all. That is also how a creation flow should behave: a half-written
invoice should not be abandonable by tapping another tab.

## 4. "0d overdue"

Invoices due today show `0d overdue`, five times on one screen. It should read
"Due today".

## 5. Stale copyright

Settings shows `© 2025 Invo Billing`. It is 2026. Derive the year rather than hardcode
it.

## 6. Two different client avatars

- Invoice list: tinted circle, two letters (`SA`)
- Estimates list: solid violet rounded square, one letter (`S`)

Same concept, same data, two designs. Pick one.

## 7. "More" tab, "Settings" title

The tab is labelled More; the screen it opens is titled Settings. Match them.

## 8. Estimate rows carry no date

Invoice rows show a date and a due state; estimate rows show neither. Add the date.

## 9. Negative money renders as `₹-380.00`

Sign after the symbol. Should be `−₹380.00`. Also worth asking whether a negative stock
value should appear at all, or be shown as a warning.

## 10. Copy error on the invoice form

"Total amount — Amount due by invoice date". It is due by the **due** date.

---

## Already fixed

- **Dashboard revenue chart** rendered as grey stubs floating in an empty box with no
  baseline or labels — indistinguishable from a failed render. Rebuilt with a baseline,
  full-height day tracks, weekday labels and a best-day figure; an empty week now says
  so in words.
- **Dead band** under the dashboard list, from `padding(.bottom, 100)` stacked on top
  of the tab bar inset the TabView already applies.
- **Server date windows** (invo-server `f308c0e`): the week's revenue changed depending
  on the time of day it was queried, and the headline covered eight days while the
  chart covered seven.

## Open question

The dashboard shows **₹14K above "No sales recorded in the last 7 days"**. Measured
directly against production, that company's last-7-days total is genuinely ₹0 — its
invoices are dated outside the window — and no window reproduces ₹14K. Needs the dev
server restarted on the current code and another look. A headline that contradicts the
chart beneath it is exactly the class of defect this rejection was about.

## Not yet examined

- Signed-in state on a small device (only the login screen was checked on iPhone 16e)
- A Release build — everything here is Debug in a simulator
- The PDF preview, the barcode scanner, and the printer flow
- Client detail, item detail, credit notes, expenses, ledger, client ageing
