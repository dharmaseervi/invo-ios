//
//  ImportItemsView.swift
//  Invo Billing
//
//  Bringing a catalogue in from a spreadsheet, in three steps: choose the file, look at
//  what the app made of it, import what you want. Nothing is written until the last
//  step, and the middle step is the whole point — a shop's product list is not
//  something to hand over blind.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportItemsView: View {
    @StateObject private var vm = ImportItemsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    /// Set when anything was written, so the items list behind this screen knows to
    /// reload when it closes.
    let onFinished: (Bool) -> Void

    private var imported: Bool { (vm.result?.created ?? 0) + (vm.result?.updated ?? 0) > 0 }

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if let result = vm.result {
                resultView(result)
            } else if vm.isReading {
                VStack(spacing: 12) {
                    ProgressView().tint(.sAccent)
                    Text("Reading \(vm.fileName ?? "your file")…")
                        .font(.scaled(13))
                        .foregroundColor(.sMutedFG)
                }
            } else if vm.preview == nil {
                chooseFileView
            } else {
                previewView
            }
        }
        .navigationTitle("Import products")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    onFinished(imported)
                    dismiss()
                }
            }
        }
        // Debug builds accept -importCSVPath <file>, which loads a file straight from
        // the Mac's filesystem. The simulator's Files app will not show a file copied
        // into it from outside, and the picker is UIKit's — neither is what this screen
        // is for. Same idea as -startScreen elsewhere; compiled out of release.
        #if DEBUG
        .task {
            guard vm.preview == nil,
                  let path = UserDefaults.standard.string(forKey: "importCSVPath")
            else { return }
            await vm.read(url: URL(fileURLWithPath: path))
        }
        #endif
        .fileImporter(
            isPresented: $showFilePicker,
            // .commaSeparatedText covers a .csv; plainText covers the ones exported
            // with a .txt extension, which spreadsheets do more often than you would
            // think. An .xlsx is not a text file and cannot be read here, which the
            // screen says before anybody goes looking for it.
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { outcome in
            guard case .success(let urls) = outcome, let url = urls.first else { return }
            Task { await vm.read(url: url) }
        }
        .alert("Import", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Step one: the file

    private var chooseFileView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "tablecells")
                .font(.scaled(40))
                .foregroundColor(.sMutedFG)

            VStack(spacing: 8) {
                Text("Import your product list")
                    .font(.scaled(17, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text("Choose a CSV file. Export one from Excel, Google Sheets or your old billing app — the columns can be named anything.")
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showFilePicker = true
            } label: {
                Text("Choose file")
                    .font(.scaled(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Text("Nothing is saved until you have seen what's in the file.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)

            Spacer()
        }
    }

    // MARK: - Step two: what we made of it

    private var previewView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 14) {
                    fileCard
                    if !vm.missing.isEmpty { missingCard }
                    if !vm.duplicateRows.isEmpty { duplicatesCard }

                    ForEach(vm.rows) { row in
                        rowCard(row)
                    }

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            importBar
        }
    }

    private var fileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(vm.fileName ?? "Your file")
                    .font(.scaled(14, weight: .semibold))
                    .foregroundColor(.sForeground)
                    .lineLimit(1)
                Spacer()
                Button("Change") { showFilePicker = true }
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sAccent)
            }

            Text("\(vm.summary.total) rows · \(vm.summary.valid) can be imported\(vm.summary.invalid > 0 ? " · \(vm.summary.invalid) need fixing" : "")")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)

            // What the app made of their columns. Worth showing plainly: if "Rate" was
            // read as the selling price when it was the purchase price, this is where
            // somebody notices, not after a thousand products have the wrong price.
            if !vm.mappedFields.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(vm.mappedFields, id: \.header) { field in
                        Text("\(field.column.label) ← \(field.header)")
                            .font(.scaled(11))
                            .foregroundColor(.sMutedFG)
                    }
                }
                .padding(.top, 2)
            }

            if !vm.unmappedHeaders.isEmpty {
                Text("Not used: \(vm.unmappedHeaders.joined(separator: ", "))")
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    private var missingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Can't import this file")
                .font(.scaled(14, weight: .semibold))
                .foregroundColor(.sDestructive)
            Text("No column was found for: \(vm.missing.map(\.label).joined(separator: ", ")). Every product needs at least a name and a selling price.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.sDestructive.opacity(0.08))
        .cornerRadius(14)
    }

    private var duplicatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(vm.duplicateRows.count) already in your products")
                .font(.scaled(14, weight: .semibold))
                .foregroundColor(.sForeground)
            Text("These are skipped unless you say otherwise. Updating replaces the price, stock and other details with what's in the file.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)

            HStack(spacing: 10) {
                Button("Skip all") { vm.setAllDuplicates(.skip) }
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sAccent)
                Button("Update all") { vm.setAllDuplicates(.update) }
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    private func rowCard(_ row: ImportRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.item.name.isEmpty ? "(no name)" : row.item.name)
                    .font(.scaled(14, weight: .medium))
                    .foregroundColor(.sForeground)
                Spacer()
                Text("Line \(row.line)")
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)
            }

            Text(detailLine(row.item))
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)

            ForEach(row.problems, id: \.self) { problem in
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.scaled(12))
                    .foregroundColor(.sDestructive)
            }
            ForEach(row.notes, id: \.self) { note in
                Text(note)
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }
            if let reason = vm.failures[row.line] {
                Label(reason, systemImage: "xmark.octagon.fill")
                    .font(.scaled(12))
                    .foregroundColor(.sDestructive)
            }

            if let duplicate = row.duplicate, row.canImport {
                duplicateControl(row, duplicate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sCard)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(row.canImport ? Color.sBorder : Color.sDestructive.opacity(0.5), lineWidth: 0.5)
        )
        .cornerRadius(14)
        .opacity(row.canImport ? 1 : 0.75)
    }

    private func duplicateControl(_ row: ImportRow, _ duplicate: ImportDuplicate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Which way it matched matters: an SKU is the same product, a name might
            // just be two products called the same thing.
            Text(duplicate.matchedOnSKU
                 ? "You already have this SKU — \(Money.text(duplicate.price)), \(duplicate.quantity) in stock"
                 : "Same name as an existing product — \(Money.text(duplicate.price)), \(duplicate.quantity) in stock")
                .font(.scaled(11))
                .foregroundColor(.sMutedFG)

            Picker("", selection: Binding(
                get: { vm.choice(for: row) },
                set: { vm.set($0, for: row) }
            )) {
                Text("Skip").tag(ImportItemsViewModel.RowChoice.skip)
                Text("Update").tag(ImportItemsViewModel.RowChoice.update)
            }
            .pickerStyle(.segmented)
        }
    }

    private func detailLine(_ item: ImportItem) -> String {
        var parts: [String] = [Money.text(item.price)]
        if !item.sku.isEmpty { parts.append(item.sku) }
        parts.append("\(item.quantity) in stock")
        if item.tax_rate > 0 { parts.append("\(Int(item.tax_rate))% GST") }
        return parts.joined(separator: " · ")
    }

    private var importBar: some View {
        VStack(spacing: 8) {
            if vm.chosenCount > 0 {
                Text(barSummary)
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            }

            Button {
                Task { await vm.importChosen() }
            } label: {
                Group {
                    if vm.isImporting {
                        ProgressView().tint(.white)
                    } else {
                        Text(vm.chosenCount > 0 ? "Import \(vm.chosenCount) products" : "Nothing selected")
                            .font(.scaled(15, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(vm.canImport ? Color.sAccent : Color.sMutedFG.opacity(0.4))
                .cornerRadius(12)
            }
            .disabled(!vm.canImport)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.sBackground)
    }

    private var barSummary: String {
        var parts: [String] = []
        if vm.createCount > 0 { parts.append("\(vm.createCount) new") }
        if vm.updateCount > 0 { parts.append("\(vm.updateCount) updated") }
        if vm.skipCount > 0 { parts.append("\(vm.skipCount) skipped") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Step three: what happened

    private func resultView(_ result: ImportResult) -> some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.scaled(44))
                .foregroundColor(Color(red: 0.086, green: 0.639, blue: 0.341))

            VStack(spacing: 6) {
                Text("Imported")
                    .font(.scaled(18, weight: .semibold))
                    .foregroundColor(.sForeground)
                Text(resultLine(result))
                    .font(.scaled(13))
                    .foregroundColor(.sMutedFG)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    vm.startOver()
                } label: {
                    Text("Import another file")
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sAccent)
                }

                Button {
                    onFinished(true)
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.scaled(15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.sAccent)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func resultLine(_ result: ImportResult) -> String {
        var parts: [String] = []
        if result.created > 0 { parts.append("\(result.created) added") }
        if result.updated > 0 { parts.append("\(result.updated) updated") }
        if result.skipped > 0 { parts.append("\(result.skipped) skipped") }
        return parts.isEmpty ? "Nothing to do." : parts.joined(separator: ", ") + "."
    }
}
