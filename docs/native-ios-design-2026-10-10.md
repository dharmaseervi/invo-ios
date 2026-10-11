# Native iOS design pass — 10 October 2026

Implemented in the local iOS checkout. Existing uncommitted work was retained; this pass did not change services, models, database code, or financial calculations.

## Shared design rules

- Use the system SF font through SwiftUI text styles. Primary row text and inputs use body (17 pt at the default setting); supporting text uses subheadline/footnote (15/13 pt); small metadata and badges use caption (12 pt). Titles and totals use the appropriate title styles. Corresponding roles match across screens, while hierarchy remains intact.
- Text uses native Dynamic Type instead of manually calculating every reading-text font size. Large decorative symbols and proportionally sized avatar artwork may retain explicit scaling.
- Custom pages share a 16 pt horizontal margin and card inset. Compact, inline, row and section spacing are 4, 8, 12 and 24 pt. Native List and Form retain their system margins.
- Background, cards, primary/secondary text and separators use UIKit semantic colors. Invo's purple accent remains; light-mode success/warning text uses darker colors for readability.
- Paired fields stack at accessibility text sizes. Shared report summaries can become vertical. Invoice names, metadata, amounts and statuses reflow rather than occupying a permanently fixed-width row.
- Shared filter chips have a minimum 44 pt hit target and announce their selected state. Credit notes, invoices, supplier details and stock filters share this treatment.
- Bank fields use the common labelled input. Authentication uses the common palette and native bordered-prominent actions instead of a separate gradient/glow button system.
- Native navigation/tab controls remain in charge of their geometry. The visible tab-bar background preference is attached inside TabView to all five tab roots, following Apple's documented preference propagation.

## Specific screen improvements

- Invoices: exact outstanding amount, adaptive summary statistics, native row margins, readable 12 pt status labels, reflow at accessibility sizes, and the bulk-action bar reserves its own safe area.
- Clients/estimates: removed duplicated leading row padding; customer avatars scale with Dynamic Type.
- Customer ledger/credit notes: system searchable controls replace separate custom search boxes; existing search/debounce behavior remains connected.
- Credit notes: removed the large enclosing filter strip, reduced excess vertical gaps, and replaced fixed summary columns with the shared adaptive summary.
- Forms: common typography/margins across billing, customers, company, purchases, expenses and account screens. The identified paired city/pincode and date fields use adaptive stacking.
- Reports, payments, stock count, cash closing, supplier screens, settings and help: the same native reading styles and page insets are used throughout.
- Print preview controls receive the same UI styling; physical label renderer sizes and PDF-generation code were not changed.

## Verification and limitations

- Full Xcode Debug build for generic iOS Simulator succeeded after the layout changes. This compiles the entire app, rather than only parsing view syntax.
- Swift source syntax and whitespace checks passed.
- No backend tests were rerun because this pass changes UI source only.
- Computer Use could not inspect the running device: it returned “Computer Use permissions are not granted.” Light/dark visual inspection, small-device layouts, VoiceOver and accessibility-size tap-through remain unverified. This document is not a claim of complete Apple HIG compliance.
- This is not a Release archive, deployment or App Store submission.

## Apple references

- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Tab-bar background propagation](https://developer.apple.com/documentation/swiftui/view/toolbarbackground(_:for:)-5ybst)

## Source coverage

The following files changed in this pass. Coverage means source review and implementation; no runtime screenshot verification is implied.

86 UI/shared-style files changed across 22 areas.

### Core

- [AdaptiveStatRow.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Core/AdaptiveStatRow.swift>)
- [DesignSystem.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Core/DesignSystem.swift>)
- [FormFieldView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Core/FormFieldView.swift>)
- [IndianStates.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Core/IndianStates.swift>)

### Ledger

- [LedgerListView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/Ledger/Views/LedgerListView.swift>)
- [LedgerView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/Ledger/Views/LedgerView.swift>)
- [StatementShareView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/Ledger/Views/StatementShareView.swift>)

### auth

- [AuthTheme.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/auth/view/AuthTheme.swift>)
- [BiometricLockView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/auth/view/BiometricLockView.swift>)
- [EmailVerificationView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/auth/view/EmailVerificationView.swift>)
- [ForgotPasswordView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/auth/view/ForgotPasswordView.swift>)
- [OTPLoginView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/auth/view/OTPLoginView.swift>)
- [loginView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/auth/view/loginView.swift>)
- [signupView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/auth/view/signupView.swift>)

### challan

- [ChallanDetailView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/challan/view/ChallanDetailView.swift>)
- [ChallanListView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/challan/view/ChallanListView.swift>)
- [CreateChallanView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/challan/view/CreateChallanView.swift>)

### client

- [ClientDetailedView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/client/view/ClientDetailedView.swift>)
- [ClientFormView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/client/view/ClientFormView.swift>)
- [ClientView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/client/view/ClientView.swift>)

### closing

- [CashClosingView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/closing/view/CashClosingView.swift>)
- [StocktakeView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/closing/view/StocktakeView.swift>)

### company

- [CompanyBankFormView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/company/view/CompanyBankFormView.swift>)
- [CompanyBankListView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/company/view/CompanyBankListView.swift>)
- [CompanyEditView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/company/view/CompanyEditView.swift>)
- [CompanyView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/company/view/CompanyView.swift>)
- [companyForm.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/company/view/companyForm.swift>)

### credit note

- [CreateCreditNoteView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/credit note/view/CreateCreditNoteView.swift>)
- [CreditNoteActionSheets.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/credit note/view/CreditNoteActionSheets.swift>)
- [CreditNoteDetailView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/credit note/view/CreditNoteDetailView.swift>)
- [CreditNoteListView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/credit note/view/CreditNoteListView.swift>)

### estimate

- [CreateEstimateView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/estimate/view/CreateEstimateView.swift>)
- [EditEstimateView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/estimate/view/EditEstimateView.swift>)
- [EstimateDetailView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/estimate/view/EstimateDetailView.swift>)
- [EstimateListView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/estimate/view/EstimateListView.swift>)
- [EstimatePrintView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/estimate/view/EstimatePrintView.swift>)

### expensess

- [EditExpenseView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/expensess/view/EditExpenseView.swift>)
- [expensessFormView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/expensess/view/expensessFormView.swift>)
- [expensessView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/expensess/view/expensessView.swift>)

### help

- [HelpView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/help/HelpView.swift>)

### home

- [homeView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/home/view/homeView.swift>)

### invoice

- [ClientPickerView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/ClientPickerView.swift>)
- [CreateInvoiceView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/CreateInvoiceView.swift>)
- [EditInvoiceView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/EditInvoiceView.swift>)
- [OverdueRemindersView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/OverdueRemindersView.swift>)
- [SelectItemSheet.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/SelectItemSheet.swift>)
- [SendEmailSheet.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/SendEmailSheet.swift>)
- [InvoiceAddressFormView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/address/InvoiceAddressFormView.swift>)
- [InvoiceCustomerSection.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/components/InvoiceCustomerSection.swift>)
- [InvoiceDetailView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/components/InvoiceDetailView.swift>)
- [InvoiceDetailsSection.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/components/InvoiceDetailsSection.swift>)
- [InvoicePrintView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/components/InvoicePrintView.swift>)
- [PDFQuickLookView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/components/PDFQuickLookView.swift>)
- [SummarySection.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/components/SummarySection.swift>)
- [itemsSection.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/components/itemsSection.swift>)
- [invoiceView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/invoice/view/invoiceView.swift>)

### items

- [BulkPrintLabelsScreen.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/BulkPrintLabelsScreen.swift>)
- [ImportItemsView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/ImportItemsView.swift>)
- [ItemFormView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/ItemFormView.swift>)
- [ItemsView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/ItemsView.swift>)
- [ItemDetailsSection.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/components/ItemDetailsSection.swift>)
- [LabelSizePicker.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/components/LabelSizePicker.swift>)
- [LabelStyleSection.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/components/LabelStyleSection.swift>)
- [PricingStockSection.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/components/PricingStockSection.swift>)
- [PrinterPickerSection.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/items/view/components/PrinterPickerSection.swift>)

### more

- [view.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/more/view/view.swift>)

### payment

- [PaymentsView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/payment/view/PaymentsView.swift>)
- [RecordPaymentView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/payment/view/RecordPaymentView.swift>)

### profile

- [ProfileView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/profile/view/ProfileView.swift>)

### purchases

- [CreateDebitNoteSheet.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/CreateDebitNoteSheet.swift>)
- [PurchaseBillDetailView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/PurchaseBillDetailView.swift>)
- [PurchaseLedgerView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/PurchaseLedgerView.swift>)
- [PurchaseSheets.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/PurchaseSheets.swift>)
- [PurchasesView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/PurchasesView.swift>)
- [ReturnToSupplierSheet.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/ReturnToSupplierSheet.swift>)
- [SupplierDetailView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/SupplierDetailView.swift>)
- [SupplierStatementShareView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/SupplierStatementShareView.swift>)
- [SupplierStatementView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/purchases/view/SupplierStatementView.swift>)

### reports

- [AgingReportView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/reports/view/AgingReportView.swift>)
- [GSTReportView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/reports/view/GSTReportView.swift>)
- [ProfitLossView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/reports/view/ProfitLossView.swift>)
- [StockReportView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/reports/view/StockReportView.swift>)
- [SupplierAgingReportView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/reports/view/SupplierAgingReportView.swift>)

### sessions

- [ActiveSessionsView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/sessions/view/ActiveSessionsView.swift>)

### staff

- [StaffView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/staff/view/StaffView.swift>)

### tab

- [tabView.swift](</Users/dharmaseervi/Desktop/Invo Billing/Invo Billing/Features/tab/view/tabView.swift>)

