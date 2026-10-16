# Invo iOS quality audit — 12 October 2026

Scope: current clean iOS checkout `/Users/dharmaseervi/Desktop/Invo Billing`, HEAD `2fc3c93` (`Fix WhatsApp reminders, stale supplier detail and review findings`). Read-only audit; no app or checked-in test changes. Reviewed auth/session, invoice list/detail/bulk actions, purchase/supplier/detail/statement flows, reports, dashboard, challans, and list/search/paging patterns in clients/items/expenses/estimates/credit notes. This is source review plus the listed executable checks, not a simulator tap-through or performance benchmark.

## Confirmed findings

### I1 — P1: invoice detail can show one invoice and act on another

Evidence: `Invo Billing/Features/invoice/viewModel/InvoiceViewModel.swift:491–503` sets `isFetchingDetail`, fetches, and assigns on success; it neither clears the previous `invoiceDetail` when the requested ID changes nor binds the result to a request generation. The list shares this model with each detail destination. `Features/invoice/view/components/InvoiceDetailView.swift:163` renders any stored detail. Payment at `473–481` uses `detail.id`, while delete at `496`, cancel at `575`, duplicate at `619`, and sharing at `636` use the destination's `invoiceID`.

Trigger: open A, return to the list, open B while offline or make B's fetch fail. A reappears in B's destination after the spinner, and actions use inconsistent IDs. This risks an operation against a different invoice from the one shown. A slow A response may also overwrite B.

Fix/acceptance: own detail state per ID, or clear on an ID change and reject superseded replies. Only enable actions when loaded ID equals route ID. Test A→B failure and A→B responses arriving out of order. Do not erase useful cached state for a same-ID refresh; show it explicitly as stale.

### I2 — P1: failed GST month load can export the previous month under the new month's name

Evidence: `Features/reports/viewModel/GSTReportViewModel.swift:79–96` leaves `report` untouched on failure. Navigation changes `selectedMonth` immediately (`37–48`). CSV header and filename come from `monthLabel` (`103`, `123`) instead of the successful response's `start/end`. Export remains enabled even while another month is loading (`Features/reports/view/GSTReportView.swift:43`).

Executable reproduction: compiled the **actual** current `GSTReportViewModel.swift` and `GSTReportModel.swift` with a small service/session stub in `/private/tmp/invo-gst-audit-main-20261012.swift`. September succeeds; October fails. Assertions confirm retained report starts `2026-09-01` while exported file and header say `October 2026`. This is an isolated view-model proof, not a server integration test.

Fix/acceptance: bind loaded report to company/period identity, display its actual period, disallow exporting it as another period, and give the failed requested period an inline Retry state. Test failed period change, export during loading, and reverse response order.

### I3 — P1/P2: bulk payment silently records every collection as cash

Evidence: `Features/invoice/viewModel/InvoiceViewModel.swift:671–689` constructs every payment with `.cash`, no reference, full remaining amount. `Features/invoice/view/invoiceView.swift:425–434` submits directly from “Mark paid” without a payment-method review. Selection includes any remaining balance without checking draft/cancelled status. After partial failure, selection is always cleared.

Impact: selecting invoices actually paid by bank or UPI produces cash transactions and can misstate cash-closing/payment-method reports. Drafts may be included and rejected, with only a failure count for recovery.

Fix/acceptance: confirmation sheet with invoice count/total, real method/date/reference, eligible status check and per-item success/failure. Require explicit common method for a batch, or collect mixed methods individually. Disable repeated submissions. Preserve failed selections. Parent audit is covering this financial issue too.

### I4 — P2: Purchases search does not affect the visible results

Evidence: `Features/purchases/view/PurchasesView.swift:37–67` displays `vm.suppliers` and returns. Search is advertised as “Invoice number or supplier” at `104–108`, but `PurchasesViewModel.swift:79–81` sends the search only to the bills request; fetched `bills` are not displayed on this screen. Suppliers are requested without search. Each debounced query also reloads the entire supplier and return collections.

Trigger: enter an invoice number or nonexistent supplier; visible supplier rows stay unchanged, although network work happens.

Fix/acceptance: define the screen as bills with supplier filters, or suppliers with supplier search and a separate bill-search destination. Display the collection actually being queried. Match the placeholder to behavior. Test no-results→clear and a match beyond the first page. Avoid refetching unrelated datasets on each query.

### I5 — P2: supplier bill history stops at 50, and filter requests can overwrite each other

Evidence: `Features/purchases/view/SupplierDetailView.swift:311–325` makes one `service.bills(...)` call. `Features/purchases/service/PurchaseService.swift:70` defaults to `limit: 50, offset: 0`. The detail renders those bills at `204–228` with no load-more action/trigger. Switching a filter starts another task (`244–248`), but the view model has no request generation/cancellation guard.

Impact: suppliers with years of bills lose access to older bills from this screen. Rapid All→Paid changes can leave All's response underneath the Paid filter; failures retain prior-filter bills without marking them stale.

Fix/acceptance: supplier-scoped paging and search, returned total/count where needed, retry footer, request identity tied to supplier/company/filter. Test at least 121 bills, rapid filter changes and page failure without duplicate rows. Do not derive the full payable from loaded bills.

### I6 — P2: session refresh is incomplete across sign-in routes and during app use

Evidence:

- Password login stores refresh token/session ID (`Features/auth/service/authService.swift:83–85`). Email verification decodes the same response but just returns it (`225`); `authViewModel.swift:116–121` saves only the access token. The current backend **does** send verification refresh/session fields (`invo-server/internal/handlers/auth.go:310–311`).
- Current OTP (`invo-server/internal/handlers/otp.go:182–189`) and password-reset responses (`auth.go:686–694`) send no refresh/session fields at all. Therefore do not describe those two as iOS throwing away returned tokens: the support is absent end-to-end. OTP access expires after 24 hours.
- `Core/Storage/SessionManager.swift:129–132` proactively calls refresh, but `AuthService.refreshAccessToken` only writes Keychain (`109–111`); it doesn't update `SessionManager.token`. Several call sites use that in-memory token, including duplicate/share (`InvoiceDetailView.swift:618`, `635`). The expired-token launch path does update it (`SessionManager.swift:143–144`).
- There is no common authenticated request layer with a single refresh-and-retry flow; services make direct URLSession requests. Root checks expiry on appearance (`Core/RootView.swift:45–46`), but app activation merely handles locking on background (`48–52`).

Impact: inconsistent session duration, incomplete device-session metadata, stale-token requests and avoidable forced login/401 failures. This is separate from backend revocation security findings handled by the security audit.

Fix/acceptance: one token/session persistence path for all successful auth; one actor serializes token rotation, publishes the new token and retries an eligible failed request once. Handle invalid-refresh versus transient/offline failures separately. Test password, OTP, verification and reset; expired access with valid refresh; concurrent 401s; offline launch; revoked refresh; logout clearing all local credentials.

### I7 — P2: stale detail problem also affects delivery challans

Evidence: `Features/challan/viewModel/ChallanViewModel.swift:43–50` retains the previous `challanDetail` for a new ID and on failure. `Features/challan/view/ChallanDetailView.swift:13–27` hides the loading screen whenever any detail exists, so A stays visible during B's load. Dispatch confirmation sends destination `challanID` (`40`) while the UI is based on retained detail.

Fix/acceptance: per-ID state and guarded actions as for I1. Test open A, open B with failed load, and out-of-order results. Do not dispatch a record whose details have not loaded in this destination.

### I8 — P2: report CSVs do not escape user text

Evidence: `Features/reports/viewModel/GSTReportViewModel.swift:118–119`, `AgingReportViewModel.swift:20`, `SupplierAgingViewModel.swift:36` append comma-separated user-controlled names directly. Commas, quotes and newlines break columns/records. Spreadsheet-leading formula characters also need an explicit safe-export policy.

Executable proof: the I2 harness exports ordinary client name `Example, Store`; its invoice row has **11 CSV cells beneath a 10-column header**. No external app was opened.

Fix/acceptance: shared CSV encoder handling quotes, commas and CR/LF; safely encode text cells that spreadsheet applications might interpret as formulas. Test names with comma/quote/newline and formula-like prefixes. Preserve number types intentionally. Report file-write failure rather than returning a nonexistent/stale file URL.

### I9 — P2: dashboard refresh replaces the whole workspace and its spinner ends early

Evidence: `Features/home/view/homeView.swift:15–20` launches a detached child `Task` from synchronous `fetch`. `.refreshable { fetch() }` (`67`) completes before the request finishes. Every refresh renders skeleton instead of existing dashboard/quick actions (`54–62`); a failure replaces all with error UI. `DashboardViewModel` correctly rejects old responses, so this is the remaining presentation/refresh-lifecycle problem.

Fix/acceptance: make refresh await actual loading; distinguish first load from refresh; keep quick actions and valid current-company data visible; show refresh progress/error inline with a Retry and stale timestamp. Clear data immediately when company identity changes to avoid showing another company's data. Test pull-to-refresh, offline refresh and switching company during an in-flight request.

### I10 — P2: empty/error states are inconsistent, especially reports

`Features/reports/view/GSTReportView.swift:14–31` renders loading or report only. On first-load failure, dismissing the alert leaves no report and no inline retry action; the “Pull to retry” instruction refers to a ScrollView that is absent in that branch. Report screens should all distinguish first-load failure, empty data, refreshing existing data, stale data, and failed later pages. Some other reports have gained ContentUnavailableView-style error UI, so do not blanket-report every report as blank.

`ProfitLossViewModel.swift:38–53` has no request identity for rapid period changes and retains old report on failure. This needs the same period/data identity contract as GST. Its export does use the returned report period, so **do not** claim its CSV is relabeled identically to GST.

### I11 — P2/P3: checked-in purchase regression scripts no longer compile

`scripts/check-purchases.sh` and `scripts/check-supplier-ledger.sh` compile `PurchaseModels.swift` without `Money.swift`, which it now requires at line `173`. Both checks fail with “cannot find 'Money' in scope”. This is a test-harness/source-list defect, **not proof that the app fails to build**. Add dependencies to the scripts then rerun; keep these scripts in CI so future refactors do not silently remove regression coverage.

## Confirmed improvements / do not reopen as still broken

- Supplier detail now derives the visible supplier from the refreshed list (`SupplierDetailView.swift:17–19`) and loads that list alongside bills (`317–320`). Sheet dismissal and cancellation trigger reload (`62–80`, `90–91`). The older findings about immutable stale payable after payment/edit, an unpopulated debit-note supplier picker, and no cancellation refresh were addressed by current code. There can still be failure/retry limitations described above.
- Invoice names are now taken from the invoice response first; per-item API calls occur only for missing names (`InvoiceViewModel.swift:513–523`). This addresses the normal N+1 detail-fetch path; measure older-server fallback if relevant.
- Invoice, client, item, estimate, expense, credit-note and supplier-ledger flows have server search/paging or request-identity mechanisms. These are useful foundations; avoid replacing them with loaded-row filtering during redesign.
- Purchase totalDue and supplier statement balance are optional and distinguish unavailable from zero. Purchase UI marks failed-refresh totals as potentially outdated.
- Expense totals are fetched from server summaries; credit notes have summary failure state; list totals are no longer universally derived from just loaded rows.
- Access/refresh tokens are stored in Keychain; release endpoint is HTTPS. The local HTTP override is inside DEBUG; it is not a release security finding.
- Semantic typography and shared AppSpacing/row primitives are widespread. Native layout still needs Dynamic Type/small-screen/VoiceOver verification, delegated to design audit.
- The library/framework was not treated as broken just because of previous sandbox build errors.

## Executed checks

| Check | Result |
| --- | --- |
| `scripts/check-money.sh` | PASS, formatting and round-trip cases |
| `scripts/check-date.sh` | PASS, Gregorian wire-date cases |
| `scripts/check-expenses.sh` | PASS, decode/create/change/clear payment method |
| `scripts/check-purchases.sh` | FAIL: missing Money source in script compilation |
| `scripts/check-supplier-ledger.sh` | FAIL: same missing Money source |
| Current actual GST view model + stub service harness | Reproduced mislabeled retained-period export and malformed CSV |

Money/date initially hit the sandbox's compiler-cache restriction, then passed with approved escalation. Root reports current full Xcode Debug build succeeds; that result belongs to root's build, not these isolated checks. No production calls or user data modifications were made.

## Cross-cutting implementation rules

1. Model loading state by resource identity: company + record ID or company + query/period/filter. A success from an older request cannot overwrite the current state.
2. Actions must use the same identity as the loaded record being displayed. Disable financial/destructive actions until this invariant holds.
3. Preserve valid current-identity content during refresh; show stale/error state explicitly. New identity must not inherit unlabelled prior content.
4. Make list totals server-authoritative and query-consistent; page history separately. Support initial error, empty, no results, refreshing, paging error and retry.
5. A single authentication transport owns tokens, bounded request timeout, refresh serialization, one safe retry, cancellation and typed errors. Do not automatically retry financial writes unless idempotency is guaranteed.
6. Search the data shown, debounce once, cancel stale work, and avoid loading unrelated modules with every keystroke.
7. Measure cold launch, warm navigation, 100/1,000/10,000-row fixtures, rapid filters, low bandwidth/offline and repeated page failures. No measured latency/FPS claim can be made from this source review alone.
8. Prioritize correctness and security before appearance changes. Native consistency is a semantic type/spacing hierarchy, not one universal font size.
