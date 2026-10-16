# Invo implementation prompt

Copy the prompt below into an implementation task. The companion review records the exact code inspected and separates reproduced defects, source-confirmed issues and unverified layout risks.

---

Improve Invo Billing into a polished, dependable native iOS business app. Use the quality bar of a well-crafted first-party iOS utility: clear hierarchy, predictable actions, readable financial information, accessible controls, fast feedback and reliable recovery.

Workspaces:

- iOS: `/Users/dharmaseervi/Desktop/Invo Billing`
- Backend/web: `/Users/dharmaseervi/Desktop/invo-server`

Read these before editing:

- `/Users/dharmaseervi/Desktop/Invo Billing/docs/full-app-review-2026-10-12.md`
- `/Users/dharmaseervi/Desktop/Invo Billing/docs/reviews/2026-10-12/security-audit.md`
- `/Users/dharmaseervi/Desktop/Invo Billing/docs/reviews/2026-10-12/ios-quality-audit.md`
- `/Users/dharmaseervi/Desktop/Invo Billing/docs/reviews/2026-10-12/design-audit.md`

The reviewed revisions were iOS `2fc3c93` and server `357a042`. Recheck the current source because some findings may already be fixed. Preserve existing user changes. Keep a checklist mapping each finding to its fix and verification. Do not treat historical notes as proof that something remains broken.

## Working rules

Implement the confirmed fixes and design improvements, using small coherent changes. Fix security and financial correctness first. Do not stop after a visual reskin or an architecture proposal. Ask for a business decision only when it materially determines accounting behavior; continue independent work while waiting.

Use synthetic data and isolated test databases. Do not test attacks against production, use personal credentials, modify real business records, push, deploy or upload an archive without the authorization appropriate to that action. Do not claim a deployment from a green health endpoint alone.

Keep the existing purple brand accent, system fonts, semantic surfaces and native navigation. Preserve Purchases and Purchase ledger as separate entries in More. Tile box/square-foot calculations are out of scope.

## Phase 1 — Security and sessions

1. Constrain every challan client, item and linked invoice to the authorized company, including consistent client/invoice relationships. Reject mixed-company input before writing anything. Audit for existing invalid references; do not silently repair production data.
2. Fix logout/password-reset revocation so old refresh credentials cannot mint access tokens with a new session version. Make the security transition and refresh rotation race-safe. Define one-device versus all-device logout behavior explicitly.
3. Bind access tokens to enforceable session identity so revoking a device stops its access as well as refresh. Plan compatibility with shipped clients and legacy tokens. Test the specific revoked session and a retained session separately.
4. Add cost permissions and company resolution for supplier-aging and debit-note PDF endpoints. Inventory every authenticated business route; each must have an explicit permission or documented exemption. Test staff, authorized roles, foreign companies and conflicting IDs.
5. Preserve the current same-origin web HttpOnly-cookie design. Ensure the development bearer-token/localStorage path cannot accidentally become the intended production configuration.
6. Unify iOS password/OTP/email-verification/reset session handling. Use one authentication transport that owns credential persistence, in-memory publication, serialized refresh, cancellation, deadlines and typed errors. Retry at most once when safe. Do not automatically replay financial writes until their idempotency is guaranteed.

Required regressions: cross-company challan references; old access and refresh after reset/logout; revoked-device access; simultaneous refresh/revocation; role-policy coverage; all iOS sign-in paths; concurrent 401s; offline launch; invalid versus temporarily unreachable refresh.

## Phase 2 — Financial and record correctness

1. Make duplicate invoice reuse the canonical decimal calculator and preserve address snapshots and intended document fields. Do not skip bad item scans and save an incomplete duplicate. The ₹100 item,18% tax,₹10 discount example must remain ₹106.20 across create/edit/duplicate, lines, PDF and report.
2. Scope invoice and challan detail state to the selected record and company. Never show A with actions targeting B. Reject obsolete responses and disable actions until displayed ID equals destination ID. Preserve explicitly stale same-record data only where safe.
3. Bind reports and exports to the successfully loaded company/period. A failed October request must never export September values under an October label. Handle loading and reverse response order too.
4. Recalculate and preserve TDS across edit, restore, duplicate and display. Include TDS and document type in draft recovery. Validate rates and decimal rounding server-side. Define gross invoice value, cash collectible, withholding and settlement separately; get the intended accounting policy before changing its legal/tax meaning.
5. Replace immediate bulk “Mark paid” with a review flow showing eligible invoices, count, exact amount, actual method, date and reference. Do not assume cash. Preserve failed selections and display per-record results. Avoid duplicate submission and unsafe retries.
6. Use one CSV encoder with correct quoting and a safe text-cell policy for spreadsheets. Handle file-write errors. Test commas, quotes, line breaks and formula-like prefixes.
7. Correct the scope of Profit & Loss. Either implement an agreed cost-of-sales/returns/tax policy or give the existing limited calculation an accurate name and explanation. Do not invent an accounting policy merely to complete the screen.

Required regressions: A→B failure/out-of-order detail; period-change export failure; mixed tax/discount rounding; copied addresses; TDS amount edit and restored draft; UPI/bank bulk payments; partial batch failure; unsold inventory and returns in the chosen report definition.

## Phase 3 — Search, loading and performance

1. Make Purchases search query the collection it actually displays. Invoice-number search must reveal matching bills; supplier search must visibly change supplier results. Do not fetch unrelated suppliers/returns on every keystroke.
2. Add complete supplier bill history with scoped pagination, filtering, retry and stale-response protection. Test at least121bills and100suppliers. Keep total payable independent of loaded pages.
3. Page unbounded challan history and use lazy collections. Reuse existing server search/summary mechanisms instead of calculating global totals from loaded rows.
4. Give every data screen explicit first-load, refresh, empty, no-results, failed, page-failed and permission-limited states. Unknown totals must say unavailable, not zero. Keep search/filter controls mounted and current-company content usable during refresh.
5. Make dashboard pull-to-refresh await the actual request. Keep quick actions accessible. Show failed sections inline with Retry; clear old-company data when the company changes.
6. Give mutations local progress and a recoverable error. Keep form data after failure. Show PDF/export progress without blocking unrelated work.
7. Repair purchase/supplier-ledger regression scripts so their Money dependency compiles. Run and retain meaningful checks in CI.
8. Profile current behavior before claiming speed improvements. Measure cold/warm loading, request count, memory and scrolling with large synthetic datasets and poor networks. Do not report estimated numbers as measured results.

## Phase 4 — Native design across every screen

Use native NavigationStack, TabView, List, Form, searchable, toolbars, sheets and share/print controls where appropriate. Let the OS manage navigation geometry and materials.

Typography is a shared hierarchy, not one universal size:

- Primary row/input: body, normally17pt.
- Secondary information: subheadline/footnote, normally15/13pt.
- Small metadata: caption, normally12pt.
- Section headings: headline.
- Key totals: title/title2 according to importance.
- Page titles: native navigation behavior.

Use the shared Money/date formatters and monospaced digits for aligned amounts. Financial work screens show exact values. Clearly label total, paid, due, credit held and supplier advance. On partial invoices, show what remains collectible alongside the original total when useful.

Custom spacing uses4/8/12/16/24pt roles; native lists/forms retain system insets. Align text, separators and amount columns consistently. Keep surfaces calm and opaque enough to read. Purple signals selection/action; status also has words or symbols.

At large text sizes, reflow identity→metadata→amount→actions and allow rows to grow. Use AdaptiveFormRow/ViewThatFits or equivalent for paired fields. Do not shrink essential money/text to compensate for rigid columns. Use44×44pt as the comfortable custom-control target. Supply accessible action names, values and selected state; label date pickers and switches even if their visual labels are separate. Respect Reduce Motion, Increase Contrast and Bold Text.

Forms need persistent labels, appropriate keyboards, focus next/done, contextual validation, one primary save action and protection against losing real unsaved work. Avoid immediate destructive Clear actions beside Save. Add Remove item to challan creation without clearing the rest of the document.

Use searchable entity sheets for large supplier/customer/item sets. Add searchable/filterable payment history and details for references, allocations and corrections. Keep optional enhancements distinct from release-blocking repairs.

Cover all modules: Home; invoice list/create/edit/detail; estimates/proforma; clients; items/import/labels; purchases/suppliers/returns; customer and supplier ledgers/statements; credit/debit notes; payments; expenses; reports; cash closing; stock count; companies/banks; staff; authentication/sessions; More/profile/help.

## Verification and completion

Follow current Apple guidance for [layout](https://developer.apple.com/design/human-interface-guidelines/layout), [typography](https://developer.apple.com/design/human-interface-guidelines/typography), [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) and [loading](https://developer.apple.com/design/human-interface-guidelines/loading). Do not claim certification or complete compliance from source changes alone.

Run meaningful backend/financial/security tests, Swift regression checks, a full current iOS build and relevant web checks. Then exercise the actual UI on small/large devices, default/largest accessibility text, light/dark, VoiceOver, Reduce Motion, keyboard-visible forms and long records. Test offline/slow/failed requests, rapid navigation, search clearing, second-page failure and company switching. Verify PDFs and physical printing separately from Swift compilation.

If device access or a required environment is unavailable, finish independently verifiable work and clearly list what remains unverified. Do not bypass a denied permission or call a screen tested because it built.

Deliver a concise change summary, a finding-by-finding fixed/remaining/verified table, test evidence, current screenshots where available, migrations/rollout requirements and any decisions still needed. A release archive should be built from the final tested code when authorized; never describe an older archive as containing new fixes.
