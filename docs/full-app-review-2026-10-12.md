# Invo: full product review — 12 October 2026

**Verdict: keep the native design direction, but fix the remaining security and business-data defects before calling this release-ready.** The app already has a useful set of business modules. The biggest opportunity is making them consistent, trustworthy and easy to recover when something fails.

Reviewed iOS `2fc3c93` and backend/web `357a042`. Both repositories were clean when this review began. This review adds documentation only; no application fixes, commits, deployment or archive were made.

## Scope and confidence

The review inventoried 195 Swift files and 89 view/core-view files. Focused reading covered shared design components and list, form, detail and action paths across all 21 feature areas. Backend review concentrated on authentication, company/role boundaries, invoice arithmetic, purchase/report paths and newer features. Web review covered authentication, route coverage, selected report/editor structure and TypeScript compilation. Android was not present in these workspaces and was not reviewed.

This is broad source coverage plus targeted executable proofs. It is not a claim that every line, screen state or production configuration was tested. The supplied screenshots predate the current code. No fresh simulator tap-through, VoiceOver run, physical printer check, Release archive or Instruments profile was completed.

Detailed evidence and acceptance criteria:

- [Security audit](</Users/dharmaseervi/Desktop/Invo Billing/docs/reviews/2026-10-12/security-audit.md>)
- [iOS correctness, loading and performance audit](</Users/dharmaseervi/Desktop/Invo Billing/docs/reviews/2026-10-12/ios-quality-audit.md>)
- [Design audit and complete screen-area matrix](</Users/dharmaseervi/Desktop/Invo Billing/docs/reviews/2026-10-12/design-audit.md>)
- [Implementation prompt](</Users/dharmaseervi/Desktop/Invo Billing/docs/implementation-prompt-2026-10-12.md>)

## 1. Fix before release

P1 means the issue can compromise data access, record identity or financial accuracy. These are current findings, not a repetition of older review lists.

| ID | Finding | Concrete consequence | Evidence |
| --- | --- | --- | --- |
| S1 | Delivery challan references are not constrained to one company | A signed-in user can attach a foreign company's customer/item/invoice and read foreign names through their own challan | Reproduced against local PostgreSQL; security audit |
| S2 | Refresh credentials survive logout/password reset | A copied refresh token restores authenticated access after those actions | Reproduced against current auth handlers; security audit |
| S3 | Device revoke leaves its access token valid | A revoked device can keep making authenticated requests until expiry or another user-wide invalidation | Reproduced with the access token minted for the revoked session; security audit |
| S4 | Supplier-aging/debit-note PDF routes lack role policies | Company staff can reach cost information hidden from their normal screens | Policy test plus handler inspection; security audit |
| I1 | Invoice detail is not scoped to the selected invoice ID | After opening A then failing to load B, the screen can display A while some actions target B | Source-confirmed state/action mismatch; iOS audit |
| I2 | GST report data and selected period can disagree | A failed October load can export September figures under an October filename/header | Executable proof using the actual view model; iOS audit |
| F1 | Duplicate invoice uses different arithmetic | Duplicating a discounted invoice changes the amount and breaks reconciliation | Actual handler exercised with a SQL capture driver; below |
| F2 | Draft edit leaves TDS amount unchanged | Editing the invoice value leaves the previous deduction and wrong net amount | Source-confirmed; below |
| I3 | Bulk “Mark paid” assumes cash | Bank/UPI collections can silently become cash entries and distort cash closing | Source-confirmed request payload; iOS audit |

### F1 — Duplicate invoice changes totals and omits address snapshots

[DuplicateInvoice](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/invoice_handler.go:1746>) recomputes totals using its own floating-point formula, subtracting the invoice discount after tax. Create/edit use [computeInvoiceTotals](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/invoice_totals.go:33>), which apportions that discount before tax.

Verified example, one item at ₹100 with 18% tax and ₹10 invoice discount:

| Path | Header total | Stored line total |
| --- | ---: | ---: |
| Existing create/edit calculator | ₹106.20 | ₹106.20 |
| Actual duplicate handler | ₹108.00 | ₹118.00 |

The handler was executed through Gin with a capture SQL driver, so this proves what the actual code sends to persistence, not an independently rewritten calculation. It was not a full live-database invoice/PDF test.

The duplicate path also makes no `invoice_addresses` inserts. [PDF generation](</Users/dharmaseervi/Desktop/invo-server/internal/services/invoice_pdf_service.go:94>) reads those snapshots, leaving copied documents without the expected billing/shipping snapshot. Item scan failures are skipped instead of failing duplication, which can additionally produce an incomplete copy.

**Fix:** use the canonical decimal calculator and a shared validated creation path; copy the intended document fields and address snapshots transactionally; fail on incomplete reads. Test no discount, invoice discount, mixed tax rates, line discounts, fractional currency, addresses and rollback.

### F2 — TDS is not maintained through editing and recovery

[CreateInvoice](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/invoice_handler.go:286>) stores a TDS rate and amount. [UpdateInvoice](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/invoice_handler.go:543>) updates total and remaining amount without recalculating `tds_amount`. The [edit screen](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/EditInvoiceView.swift:136>) passes a constant zero TDS rate into its summary.

For example, a draft with total ₹1,000 and 10% TDS stores ₹100. Changing the total to ₹2,000 leaves ₹100 instead of updating the deduction according to the app's existing rule. This is an internal consistency finding, not an assessment of statutory TDS treatment.

Related gaps:

- [Local draft storage](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/model/InvoiceDraft.swift:40>) omits both TDS and document type. [Restore](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/viewModel/InvoiceViewModel.swift:745>) cannot recover them.
- Detail/PDF display a net receivable after TDS, while issue/payment accounting uses the full invoice balance. There is no corresponding TDS settlement path in the reviewed payment service. A customer paying the displayed net amount can remain part-paid. Gross invoice value, cash due and withholding need separate, explicit definitions.
- The server DTO accepts an unrestricted TDS rate; a bounded validation policy is needed independently of the iOS picker.

**Fix:** define the withholding lifecycle and rounding once, preserve it across creation/edit/restore/duplicate, and reconcile invoice, payment, ledger, PDF and reports. Do not merely subtract TDS from an outstanding balance without recording why that portion is settled. Obtain the intended accounting rule before implementing jurisdiction-dependent treatment.

## 2. Correctness and scale issues for the next pass

| Issue | Required improvement |
| --- | --- |
| Purchase search loads filtered bills but displays suppliers | Search the visible collection; make bill-number search return visible matching bills; do not reload unrelated datasets on each query |
| Supplier detail fetches only the first 50 bills | Add supplier/filter-scoped pagination, search and page retry; test 121+ bills and out-of-order responses |
| Challan detail can retain another challan's data | Scope detail and dispatch action to the same loaded record ID |
| Session support varies by sign-in route | Unify verification, password, OTP and reset persistence; keep in-memory and Keychain tokens synchronized; serialize refresh |
| Report CSVs directly concatenate names | Escape commas, quotes and line breaks; define safe spreadsheet-text handling; surface file-write errors |
| Dashboard refresh discards usable content and finishes its refresh closure early | Await the request; preserve current-company content/actions with an inline refresh/error state |
| Some first-load report failures leave a blank screen | Persistent inline error and Retry, distinct from no data; export only the loaded period/company |
| Purchase regression scripts fail to compile | Add the required Money source dependency and restore CI coverage; these failures do not mean the app itself fails to build |

See I4–I11 in the iOS audit for source locations and acceptance tests.

### F3 — “Profit & Loss” currently overstates what it calculates

[The handler](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/profit_loss_handler.go:68>) adds invoice totals, subtracts all purchase-bill totals and expenses in the period, and labels the results gross/net profit. It does not account for unsold inventory or include credit-note/purchase-return adjustments in those queries. Buying ₹1,00,000 of unsold stock therefore reduces the displayed period result by ₹1,00,000 immediately.

For an inventory business, period purchases and cost of inventory sold are different concepts; [IAS 2's overview](https://www.ifrs.org/issued-standards/list-of-standards/ias-2-inventories/) describes recognizing inventory cost with the related sales. This reference explains the conceptual distinction, not which reporting standard applies to each Invo customer.

**Required product decision:** implement a documented cost-of-sales policy with returns/tax handling, or rename and explain this as a limited sales/purchases/expenses summary. Do not present it as a complete accounting profit statement until its scope supports that label. Priority P2, elevated if customers rely on this report for decisions.

## 3. Design direction: calm, native, precise

The existing system font, purple accent, semantic backgrounds, native navigation and grouped More screen are a good foundation. Keep them. Visual quality now depends on consistent hierarchy, readable numbers, clear actions and stable states.

Apple's guidance favors adaptable system typography, familiar controls and layouts that respond to the person's settings. Use semantic font APIs rather than hardcoded font names. [Apple Fonts](https://developer.apple.com/documentation/technologyoverviews/fonts), [Apple Layout](https://developer.apple.com/design/human-interface-guidelines/layout).

### Typography and alignment contract

These are proposed Invo conventions; Apple does not prescribe this exact spacing system for every app.

| Role | Convention |
| --- | --- |
| Primary row title and input | `.body`, regular or medium; default 17pt |
| Secondary line | `.subheadline` or `.footnote`, default 15/13pt |
| Minor metadata/status | `.caption`, default 12pt, with adequate contrast |
| Section heading | `.headline` |
| Important total | `.title2` / `.title`, size and weight chosen by hierarchy |
| Page title | Native navigation title behavior |
| Financial values | Shared Money formatter, exact values in work screens, monospaced digits |
| Custom spacing | 4/8/12/16/24pt roles; retain native List/Form insets |

“Same typography” means the same role uses the same style. It should not mean every title, amount and note has the same size.

At large text sizes, stack the customer/item identity, metadata, amount and actions. Allow row height to grow. Do not solve large-text layouts by shrinking money to 60% or forcing every label to one line. Align financial amounts consistently and label **Invoice total**, **Paid**, **Amount due**, **Customer credit** and **Supplier advance** distinctly.

### Changes that will be most visible to users

1. **Home:** keep Create invoice/Add client available while totals refresh. Reflow cash-position tiles. Make a failed section retryable without replacing the whole dashboard.
2. **Invoices:** retain native list/search. Partial invoices should show a labelled amount due and secondary original total. Use a review sheet for bulk payments with amount, method and date.
3. **Forms:** one primary Save/Create action, persistent labels, sensible keyboards and field validation. Protect unsaved work, including interactive dismissal where applicable. Remove immediate destructive Clear from the main action row.
4. **Suppliers/purchases:** searchable supplier selection, visible complete bill history, readable balance/payment rows. Keep Purchases and Purchase ledger separate as requested.
5. **Payments:** searchable history with date/customer/method filters and a detail screen for full references, allocations and corrections.
6. **Reports:** clear loaded period, inline Retry, accessible aging information and exports that match the displayed dataset.
7. **Challans:** add Remove item without discarding the entire document. Scope dispatch to the loaded record.
8. **More/security/printing:** label switches and icon actions; use native navigation/stepper controls; organize low-frequency actions into existing groups.

### Accessibility work still required

The source contains unlabeled date/type controls and switches, small Edit/Delete/print controls, 26pt quantity buttons, rigid columns and aging colors outside the shared palette. The design appendix gives exact files. Use 44×44pt as the app's comfortable custom-target convention; provide names/values/selection state for assistive technologies. Make age/status information readable without color. Respect Reduce Motion in shimmer and decorative effects. Measure contrast in actual light/dark appearances. [Apple Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

These are source-confirmed constraints and missing semantics. Exact clipping and VoiceOver output must be checked on the running current build before claiming the visual pass is complete.

## 4. Loading and performance contract

Every list/report needs explicit first-load, refresh, populated, empty, no-search-results, failed, page-failed and permission-limited states. Every save needs submitting, success and recoverable failure. Unknown totals are unavailable, not zero. Cached results must be labelled stale and must belong to the currently selected company and query.

Keep unrelated work usable while loading and communicate progress at the affected scope. This follows [Apple's loading guidance](https://developer.apple.com/design/human-interface-guidelines/loading).

Implementation priorities:

- Tie state to company + record/query/filter/period; reject superseded replies.
- One authenticated transport with timeouts, cancellation, typed errors and serialized refresh. Retry a request only when safe; financial writes need idempotency before automatic replay.
- Page bill/challan histories and use lazy rendering. Challan listing currently has no SQL limit; see [ListChallans](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/challan_handler.go:96>).
- Avoid refetching every supplier/return on purchase search and avoid eager loading just to calculate totals. Keep summaries server-authoritative.
- Show PDF generation progress in its own action/sheet. Preserve usable lists while a document is generated.
- Keep expensive export/file work off the main interaction path when profiling shows it blocks input; debounce draft persistence without losing the final edit.

No latency, memory or frame-rate measurements were made. Suggested acceptance workloads: 100 suppliers, 1,000 customers/items, 10,000 invoices/payments, and 121 bills for one supplier; slow network, offline launch, failed second page, rapid company/filter switches and a response arriving after navigation away. Record actual cold/warm timing, request counts, scrolling hitches and memory before setting numerical budgets. “Fast” should be demonstrated, not inferred from `LazyVStack` alone.

## 5. Features: what exists and what is worth adding

Source already contains invoices, estimates/proforma, customers, catalogue/stock, CSV import, label printing, purchases including amount-only bills, suppliers and ledgers, customer payments, expenses, credit/debit notes, purchase returns, statements/PDFs, delivery challans, aging/GST/stock/profit reports, cash closing, stock counts, staff roles, sessions and biometric lock. Presence does not mean every edge case is complete. TDS and sessions specifically need the lifecycle fixes above.

The highest-value additions now are completion of everyday workflows:

- Searchable payment history and receipt/detail inspection.
- Searchable supplier selection and complete paged supplier history.
- Reliable draft recovery preserving every financial field.
- Clear batch-payment review and per-record retry results.
- Revocable/expiring public invoice links and clear sharing status; current share-token generation reuses a token and exposes no revoke/expiry control in the reviewed path.
- Visible, attributable history for financial corrections and a tested backup/restore process. Existing stock movements and restore documentation are foundations; a production restore drill was not verified here.

Web parity is incomplete in the checked-out route inventory: there are no dedicated purchase, supplier-ledger or challan pages, while iOS has those modules. Decide which web workflows are supported and communicate that explicitly before advertising identical capability.

Tile box/square-foot calculations remain excluded, as requested. More dashboards or decorative effects should come after the existing workflows are dependable.

## 6. Improvements already present

- Shared semantic typography, spacing, summary cards and adaptive invoice rows.
- Native list/search patterns and grouped More modules.
- Supplier detail refreshes after payment, return, debit note and cancellation; it now reads refreshed supplier data.
- Reminder links use the current `wa.me` flow; reminder errors no longer masquerade as all-paid.
- Expense totals and several ledger/credit summaries are server-backed, with unavailable states.
- Normal invoice detail avoids the old per-item name-fetch pattern when names are provided.
- Production-style web cookie authentication replaces old localStorage tokens.
- Backend request deadlines and numerous company/role/transaction checks exist.

Do not undo these improvements during a redesign or reopen them solely because an old review document says they are missing.

## 7. Verification performed

| Check | Result and limits |
| --- | --- |
| Current Xcode Debug, generic iOS Simulator build | Passed; code signing disabled; not a Release archive or device run |
| Backend `go test -count=1 ./...` | Passed; tests requiring a configured database can skip in this command |
| Web `tsc --noEmit --incremental false` | Passed; not browser behavior or production build verification |
| Money/date/expense Swift regression scripts | Passed |
| Purchase/supplier-ledger Swift scripts | Failed: missing Money source in script inputs |
| Security overlay + temporary PostgreSQL | Reproduced cross-company challan disclosure and refresh/device-revocation weaknesses; confirmed role-policy omissions |
| Duplicate handler + capture SQL driver | Reproduced header/line/canonical-total mismatch and absence of address writes |
| Actual GST view model + stub service | Reproduced previous-month data exported under the new month and malformed CSV for a comma-containing name |

The first sandboxed Xcode attempt failed while validating the printer framework. The approved build outside that sandbox passed. There is no basis here to report the framework as damaged.

## 8. Recommended delivery sequence

1. Security boundaries and revocation, with local regression tests and a backward-compatible client/server rollout plan.
2. Record identity, report periods, duplicate/TDS arithmetic and bulk payment correctness.
3. Shared loading/transport/pagination contracts and restoration of broken test harnesses.
4. Apply native design/accessibility rules screen by screen; begin with invoice creation/collection and supplier/payment work.
5. Run the current app on small and large devices, default and largest text, light/dark, VoiceOver, Reduce Motion and adverse networks. Verify actual PDFs and physical printing separately.
6. Build a fresh Release archive, verify the deployed server revision/behavior with authorized test data, then perform release review.

This review does not establish that the app was hacked, that production contains every local defect, or that passing a build makes it safe. It identifies concrete local release blockers and a practical route to the level of finish requested.
