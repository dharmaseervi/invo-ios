# Invo iOS design and usability audit — 12 October 2026

Reviewed current iOS checkout `/Users/dharmaseervi/Desktop/Invo Billing`, HEAD `2fc3c93`. The checkout was clean at inspection. This is a source audit, not a claim that all screens were exercised on a simulator. The supplied screenshots predate the current code, so they are useful context only. No application files were modified.

## Assessment

The app has a substantially better foundation than the earlier screenshots: native tab/navigation controls, native lists in the main modules, consistent purple accent, semantic light/dark surfaces, shared summary components, Dynamic Type text styles, and grouped More sections. It does not need a fashionable visual restart. The next step is finishing consistency and making difficult states and common business tasks reliable.

The remaining gaps are significant: accessibility adaptation is concentrated in the invoice list and report summaries; many other screens retain rigid rows, undersized custom controls and incomplete accessible labels. Financial actions, document forms, loading failures and long data need more attention than decorative styling.

## Specific findings

Paths below are relative to the iOS repository. P1 means release-critical when reproduced; P2 means fix in the next quality pass; P3 means polish. Layout risks are explicitly distinguished from observed runtime defects.

### D1 — P2: Important custom controls lack useful accessible names and comfortable targets

- `Invo Billing/Features/more/view/view.swift:199` and `:421`: Face ID and notification switches use `Toggle("")` and hide labels; nearby independent Text is not an explicit accessible association.
- `Invo Billing/Features/invoice/view/components/InvoiceDetailsSection.swift:32`, `:43`, `:50`: invoice type and both date pickers have empty labels. Add the real label to the control, even when visually hidden.
- `Invo Billing/Features/invoice/view/components/itemsSection.swift:213`: Edit/Delete are footnote-sized SF Symbols without explicit action labels or enlarged targets. Identify both the operation and item for VoiceOver.
- `Invo Billing/Features/items/view/BulkPrintLabelsScreen.swift:116`: quantity buttons are explicitly 26×26 pt.
- `Invo Billing/Features/items/view/ItemsView.swift:437`: the QR symbol actually opens printing, but has no semantic action name or explicit minimum target.
- `Invo Billing/Features/reports/view/GSTReportView.swift:63`: previous/next month controls are 32×32 pt, with no explicit month-navigation labels.
- `Invo Billing/Features/items/view/components/PricingStockSection.swift:154` and `:192`: the custom field helpers use placeholder as field label rather than the persistent field title, unlike the newer shared `FormFieldView`.

Use 44×44 pt as this app's comfortable custom-control standard; retain native controls' own geometry. Supply meaningful labels, values, selected states and hints where needed. Do not claim VoiceOver output is verified until a device pass is run. SF Symbols can have automatic descriptions; those are not a substitute for “Print labels for [item]”.

Acceptance: all task controls can be found and operated with VoiceOver, Switch Control and large text; no row unintentionally activates when its adjacent action is pressed.

### D2 — P2: Dynamic Type support exists, but most layouts do not yet reflow

- `home/view/homeView.swift:259`: the three cash-position tiles remain in one HStack. Their values and captions are forced to one line at `:293` and `:298`.
- `items/view/components/PricingStockSection.swift:26` and `:54`: paired cost/selling and stock/alert fields stay side-by-side at every text size.
- `client/view/ClientFormView.swift:69`: city and state stay side-by-side.
- `invoice/view/components/SummarySection.swift:56`: discount field has a fixed 80pt width (`:73`), while labels, TDS selector and totals stay in horizontal rows.
- `purchases/view/PurchasesView.swift:198`: supplier name, subtitle, amount and Pay share one horizontal row. The name/subtitle each permit one line and the amount reserves at least72pt. `PurchaseLedgerView:94` uses a similar row.
- `estimate/view/EstimateListView.swift:185`, `payment/view/PaymentsView.swift:121`, `Ledger/Views/LedgerListView.swift:162`, `credit note/view/CreditNoteListView.swift:265`: invoice-like rows have no accessibility-size stacked layout; some metadata is always a single line.
- `Core/Money.swift:127`: `.moneyLine()` permits shrinking text to60%. This prevents splitting money but can also undo the legibility benefit of larger text settings. Prefer a wider stacked amount before reducing its size.

These are source-confirmed constraints and high-confidence layout risks, not screenshot-proven clipping on the current build. Reuse the invoice row's adaptive layout: at accessibility sizes show identity, metadata, then amount/status; remove decorative avatar space when needed. Use `AdaptiveFormRow` or `ViewThatFits` for paired fields. Allow row height to grow. Large amounts must remain exact and readable.

Acceptance: small iPhone and largest accessibility text size; long company/client/item names; invoice numbers; ₹99,99,99,999.99; positive/negative balances; no clipped controls or essential information.

### D3 — P2: Report failure states and dashboard refresh interrupt work

- `reports/view/GSTReportView.swift:14`: only loading, empty report and nonempty report branches. A first failure followed by dismissing the alert leaves no inline error/Retry screen.
- `reports/view/AgingReportView.swift:10`: same missing failure branch.
- `home/view/homeView.swift:53`: every dashboard load/error replaces the entire dashboard, including Create invoice/Add client quick actions. `:67` calls `fetch()` from refreshable; `fetch()` (`:15`) launches its own Task rather than awaiting the request.

Use separate first-load, refresh, empty, no-results, failed, pagination-failed and submitting states. Preserve useful content and actions during refresh; mark old figures as stale when appropriate. Show a persistent inline Retry for the failed section. Never turn an unknown figure into zero. The state-correctness audit should validate related data races.

### D4 — P2: Aging colors bypass the semantic palette and carry information without text

`reports/view/AgingReportView.swift:88` defines fixed orange/red RGB colors and reuses them for small amount text (`:134`), including supplier aging. The 90+day red has no lighter dark-mode variant. Numerical contrast estimates using white and an example dark grouped surface #1C1C1E are ~3.04:1 for the orange on white and ~2.49:1 for the darkest red on dark. Actual rendered backgrounds/Increase Contrast still require runtime measurement.

The per-client row's age distribution is only the colored bar (`:139`); it has no text or accessible description of the bucket amounts. Add semantic dark/light age colors and a textual/VoiceOver summary (“₹… is over90days”), or a drilldown. Color must supplement the aging information.

### D5 — P2: A mistakenly selected delivery-challan item cannot be removed

`challan/view/CreateChallanView.swift:120` renders item lines with plus/minus quantities, with a minimum of1 (`:134`); there is no remove control or swipe deletion. Cancel (`:186`) clears the whole form. Add an explicit Remove item action or native editable list; preserve all other entered fields.

Acceptance: add two products, remove the wrong one, change quantity, retain client/date/notes and the remaining product.

### D6 — P2: Invoice collection rows hide the amount still owed

`invoice/view/invoiceView.swift:566` always displays `invoice.total`, including partial invoices. The badge says Partial but the amount remaining is not visible. On a screen headed Outstanding, this makes collection work unnecessarily ambiguous. Show a labelled amount due for issued/partial/overdue invoices, with invoice total secondary when different; keep paid/draft rows explicit. Do not silently replace total with balance without a label.

### D7 — P2: Payments are hard to find and inspect at business scale

`payment/view/PaymentsView.swift` has a paged list but no search, date range, customer/method filter, or payment detail destination. References, invoice allocations and reversal reasons are combined and truncated to one line (`:127`, `:140`, `:191`). A shop with thousands of payments cannot readily find a disputed receipt or read a full reason.

Add server-backed search/filtering, payment detail with full allocation/reference/audit information, and a receipt-share action if supported by the backend. Keep reversal/move/refund in a clearly labelled action menu, with amount/client confirmation. This is a usability feature gap rather than a visual defect.

### D8 — P2: Form behavior is inconsistent and destructive reset is too easy

Invoice and estimate creation already protect Cancel when there is unsaved work. Other forms do not apply this consistently. `client/view/ClientFormView.swift:120` and `items/view/ItemFormView.swift:83` put a prominent Clear button beside the main save workflow and immediately erase the form. `purchases/view/PurchaseSheets.swift:265` dismisses a bill on Cancel without an unsaved-work check. `CreateChallanView:186` clears on Cancel. No `interactiveDismissDisabled` appears in the scanned view source.

Use a shared dirty-form policy: discard confirmation only when work exists, protect interactive dismissal where it would lose work, preserve entered values on validation/network failure, keep a single primary save action. Move Clear to a secondary menu or remove it from routine entry. Do not prompt on every harmless navigation. Invoice draft recovery is a good pattern to extend selectively.

Also avoid starting a fresh form in an error state: `ClientFormView:33` marks the empty name Required immediately. Explain required fields up front, then display error text after interaction or attempted submission.

### D9 — P2: Some selections do not scale to hundreds of suppliers

`purchases/view/CreateDebitNoteSheet.swift:120` and supplier selectors in `PurchaseSheets.swift` enumerate all suppliers inside a Picker. A searchable supplier sheet with name/phone, balance and a contextual Add supplier action is easier at100suppliers. Preserve Purchase ledger and Purchases as separate More entries as requested; the first is account history, the second bill/return/payment work. Clarify that distinction in subtitle/empty-state copy.

### D10 — P3: Motion and document controls need a native finishing pass

- `home/view/homeView.swift:579`: shared shimmer animates forever without checking Reduce Motion; all skeleton users inherit this. Use static redaction when Reduce Motion is enabled and hide decorative skeletons from accessibility while announcing one loading status.
- `invoice/view/components/InvoicePrintView.swift:29`: manually drawn Back/title/action header, despite native navigation being used elsewhere. Use a native toolbar and adapt copy/template controls at large text. Share icons should open sharing; a menu containing print/test-page actions should have an appropriate menu label.
- `closing/view/StocktakeView.swift:71`: count editor only supplies a fixed300pt sheet. Offer a large detent or content-responsive sizing for accessibility and keyboard use.
- `invoice/view/invoiceView.swift:417`: bulk bar contains a flexible Spacer while installed as a bottom safe-area inset (`:97`). This is a layout risk requiring runtime reproduction; reduce it to its intrinsic bar height if selection makes the list collapse.

## Whole-app coverage and screen direction

Structural scan covered195Swift files;89view/core-view files were inventoried. Focused manual reading covered shared components and representative/list/form/detail/action paths across every feature area. This is not a claim that every line or runtime state was tested.

| Area | Preserve | Next design work |
| --- | --- | --- |
| Home | Company selector, native title, quick actions, real data | Retain actions while loading; adaptive totals; readable time period/comparison; figures navigate to their related work |
| Invoices | Native List/search, status chips, adaptive row | Clear total-versus-due labels, safe bulk action review, stable search during states |
| Invoice creation/edit | Customer→details→items→summary, draft recovery | Consistent native form labels/keyboard navigation, line targets, accessible TDS/discount/date rows |
| Estimates/proforma | Separate pre-sale flow, native list | Distinguish estimate/proforma visibly, adaptive row, common document form behavior |
| Clients | Search and native rows | Consistent Client/Customer terminology, full contact data, unsaved-form protection |
| Items | Catalogue search, stock badges, scan/import | Adaptive product row; contextual print action; searchable paged pickers; single primary form action |
| Import | Preview, mapping, duplicate choices, summary | Label mapping/duplicate controls; explain updates before confirming; comfortable large-text rows |
| Labels/printing | Physical label options, preview | Native stepper-sized targets, readable choices, persistent generation errors |
| Purchases/suppliers | Record bill, payment, returns, account separation | Searchable supplier selection; adaptive payment rows; visible history/filtering; clear bill-vs-ledger entry |
| Purchase/customer ledger | Summary, pages, statement export | Full descriptions and dates, accessible debit/credit meaning, consistent row/detail hierarchy |
| Credit/debit notes | Apply/refund distinction, explanations | Match form action language and dirty-state policy; accessible quantity/amount controls |
| Payments | Reversal reason, movement/refund workflows | Search/filter, detail/history/receipt workflow, large-text row adaptation |
| Expenses | Server summary, native list, date/category filtering | Same filter-chip targets and form actions; inline empty/error distinction |
| Reports | Adaptive summary helper and exports | Persistent error states; semantic age colors; accessible charts; consistent period selection |
| Cash closing | Native Form, arithmetic breakdown, readiness check | Readable full history, clear correction action and save progress |
| Stock count | Native Form/List, variance explanation, finish confirmation | Large sheet, scalable picker, preserve count editor on save failure |
| Company/banks | Shared fields, selection state, separated bank setup | One form style, readable long company/state/account labels, clear save validation |
| Staff | Role explanations, removal confirmation | Consistent role/action labels; accessible row actions; invite/setup copy clarity |
| Sessions/security | Current-device badge, revoke actions, retry | Promise only what revocation implements; descriptive session identifiers/time/device information |
| Authentication | System font, native primary button, OTP autofill label | Comfortable show-password/back targets, keyboard/Dynamic Type verification |
| More/profile/help | Native grouped sections, restrained icons | Use one vocabulary, avoid duplicated account actions, label toggles, optional module search |

## App-wide design rules to implement

These are proposed Invo conventions, not a claim Apple prescribes these exact numerical tokens.

1. Keep native `NavigationStack`, `TabView`, `List`, `Form`, `.searchable`, toolbars, sheets and system share/print controls. Let the OS supply contemporary control materials; avoid making every financial content card translucent.
2. One SF typography hierarchy: primary row/input `.body`, secondary `.subheadline`/`.footnote`, metadata `.caption`, section `.headline`, large totals `.title`/`.title2`. Corresponding roles must match; making every label the same size would remove hierarchy. Existing semantic styles already solve most fixed-font problems.
3. Shared spacing4/8/12/16/24pt for custom content; use native list/form insets where available. Align names, amounts, separators and button edges. Match card corners by role rather than adding custom variation per screen.
4. Use primary/secondary semantic text and system surfaces. Purple communicates action/selection; red destructive/overdue; green successful/settled. Add words/symbols to status. Do not use color alone.
5. Financial numbers are exact in work/decision screens and monospaced for alignment. Compact amounts may be used in a dashboard if exact values are accessible on tap. Distinguish Total, Paid, Due, Credit held and Supplier advance explicitly.
6. Reflow before truncating or shrinking: at accessibility sizes, stack identity→metadata→amount→actions; allow multiline names and dates; grow controls with text. Remove decorative avatars if they compete with necessary content.
7. One primary action per form and clear Cancel. Persistent field labels, suitable keyboard/content types, field-level validation, focus next/done behavior and draft protection. Never make a save failure look like success.
8. Every data screen needs defined first-loading, refreshing, populated, empty, search-empty, failed, page-failed and permission-limited states. Keep controls stable. Retry at the failed scope. For slow mutations show progress at the action and prevent duplicate submission.
9. Use searchable sheets for long entity lists and paged/lazy collections. Remember filters when returning from a detail. Preserve scroll position when appending/prepending pages. No full-screen spinner for a single PDF or row action if other work can continue safely.
10. Test actual UI at small/large screen, default/largest accessibility text, light/dark, Bold Text, Increase Contrast, Reduce Motion, VoiceOver, keyboard shown, long records, empty/offline/slow/error/pagination scenarios. Source review and a successful build cannot substitute for this.

## Suggested information architecture

Keep the existing five tabs unless usage data justifies a change: Home, Invoices, Clients, Items, More. More already has useful groups. Maintain Sales (Estimates/proforma, credit notes, delivery challans), Purchases (Purchases, Purchase ledger), Money (customer payments, expenses, customer ledger, cash closing), Inventory, Reports, Business, Settings, Security and Support. Move Overdue reminders closer to sales/collection work rather than hiding it among analytical reports. Optional searchable More is preferable to adding more tabs as modules grow.

## References

- [Apple Layout](https://developer.apple.com/design/human-interface-guidelines/layout): preserve familiar structure, alignment, safe areas and adaptable layouts.
- [Apple Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): readable text, comfortably operable controls and alternatives to color/motion cues.
- [Apple Loading](https://developer.apple.com/design/human-interface-guidelines/loading): show useful content promptly, communicate progress and allow unrelated work while loading.
- [Apple Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles): guide the quality bar; this review does not assert Apple certification or complete HIG compliance.

## Verification limits

No new screenshot, tap-through, accessibility-tree inspection, Instruments benchmark, Dark Mode contrast capture or VoiceOver run was performed. Computer Use was previously unavailable; no shell UI automation was used to bypass that. Security and backend/data integrity are handled by the parallel audit and should take precedence over visual polish when they conflict.
