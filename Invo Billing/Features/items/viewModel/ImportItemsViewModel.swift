//
//  ImportItemsViewModel.swift
//  Invo Billing
//

import Combine
import Foundation

@MainActor
final class ImportItemsViewModel: ObservableObject {

    /// What happens to one row when Import is tapped.
    enum RowChoice: String {
        case create, update, skip
    }

    // MARK: - State
    @Published private(set) var fileName: String?
    @Published private(set) var preview: ImportPreview?
    @Published private(set) var isReading = false
    @Published private(set) var isImporting = false
    /// Set once the import has been written. The items list reloads when this screen
    /// closes, so there is no change notification to send.
    @Published private(set) var result: ImportResult?

    @Published var errorMessage: String?
    @Published var showError = false
    /// Rows the server refused to write, by line, shown against the rows themselves.
    @Published private(set) var failures: [Int: String] = [:]

    /// The decision for each row, by line. Set when a preview arrives and then only by
    /// the person.
    @Published private(set) var choices: [Int: RowChoice] = [:]

    private let service = ItemImportService()

    // MARK: - Derived

    var rows: [ImportRow] { preview?.rows ?? [] }
    var summary: ImportSummary { preview?.summary ?? .empty }

    /// Fields the file has no column for. Without a name and a price there is nothing
    /// to import, so the screen says so rather than letting someone tap Import and
    /// watch every row fail.
    var missing: [ImportColumn] { preview?.missing ?? [] }
    var canImport: Bool {
        !isImporting && missing.isEmpty && chosenCount > 0
    }

    var createCount: Int { choices.values.filter { $0 == .create }.count }
    var updateCount: Int { choices.values.filter { $0 == .update }.count }
    var skipCount: Int { choices.values.filter { $0 == .skip }.count }
    var chosenCount: Int { createCount + updateCount }

    /// Which column was read into which field, for the "what we made of your file" line.
    var mappedFields: [(header: String, column: ImportColumn)] {
        (preview?.mapping ?? [:])
            .map { (header: $0.key, column: $0.value) }
            .sorted { $0.column.label < $1.column.label }
    }

    var unmappedHeaders: [String] {
        guard let preview else { return [] }
        return preview.headers.filter { preview.mapping[$0] == nil }
    }

    // MARK: - Reading a file

    func read(url: URL) async {
        isReading = true
        defer { isReading = false }

        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }

        // A file from the Files app lives outside the sandbox, so it has to be opened
        // with permission and closed afterwards — without this, reading returns nothing
        // and the screen would look as though the file were empty.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            show("That file could not be opened.")
            return
        }

        // Spreadsheets exported on Windows are often not UTF-8. Latin-1 is the common
        // fallback and never fails, so a file with a ₹ sign or an accented name still
        // reads rather than being rejected as unreadable.
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        else {
            show("That file isn't readable as text. Export it as CSV and try again.")
            return
        }

        fileName = url.lastPathComponent
        result = nil
        failures = [:]

        do {
            let preview = try await service.preview(companyID: companyID, csv: text)
            self.preview = preview
            resetChoices(for: preview)
        } catch {
            self.preview = nil
            show(error.localizedDescription)
        }
    }

    /// The opening position: import what can be imported, leave broken rows alone, and
    /// leave anything that already exists alone too. Updating somebody's existing
    /// prices and stock is the one thing an import should never do without being asked.
    private func resetChoices(for preview: ImportPreview) {
        var next: [Int: RowChoice] = [:]
        for row in preview.rows {
            if !row.canImport {
                next[row.line] = .skip
            } else if row.duplicate != nil {
                next[row.line] = .skip
            } else {
                next[row.line] = .create
            }
        }
        choices = next
    }

    // MARK: - Choices

    func choice(for row: ImportRow) -> RowChoice {
        choices[row.line] ?? .skip
    }

    func set(_ choice: RowChoice, for row: ImportRow) {
        // A row the server refused cannot be imported whatever is chosen, so the
        // control is not offered for it and this guards the same rule.
        guard row.canImport else { return }
        choices[row.line] = choice
    }

    /// "Update all" / "Skip all" for the rows that match something already there.
    func setAllDuplicates(_ choice: RowChoice) {
        for row in rows where row.duplicate != nil && row.canImport {
            choices[row.line] = choice
        }
    }

    var duplicateRows: [ImportRow] { rows.filter { $0.duplicate != nil } }

    // MARK: - Importing

    func importChosen() async {
        guard let companyID = SessionManager.shared.selectedCompanyId else {
            show("Select a company first.")
            return
        }
        guard canImport else { return }

        isImporting = true
        defer { isImporting = false }
        failures = [:]

        let actions: [ImportAction] = rows.compactMap { row in
            switch choice(for: row) {
            case .skip:
                return ImportAction(line: row.line, action: "skip", item: row.item)
            case .create:
                return ImportAction(line: row.line, action: "create", item: row.item)
            case .update:
                guard let duplicate = row.duplicate else { return nil }
                return ImportAction(
                    line: row.line, action: "update", item_id: duplicate.item_id, item: row.item
                )
            }
        }

        do {
            result = try await service.apply(companyID: companyID, rows: actions)
        } catch let error as ImportError {
            // Nothing was written: the server does the whole import or none of it. The
            // rows it named are marked so they can be found in the list rather than
            // hunted for in the file.
            failures = Dictionary(
                uniqueKeysWithValues: error.failures.map { ($0.line, $0.reason) }
            )
            show(error.message)
        } catch {
            show(error.localizedDescription)
        }
    }

    func startOver() {
        preview = nil
        fileName = nil
        result = nil
        choices = [:]
        failures = [:]
    }

    private func show(_ message: String) {
        errorMessage = message
        showError = true
    }
}
