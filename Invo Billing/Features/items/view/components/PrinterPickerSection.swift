import SwiftUI

/// Backend + printer + auto-cut picker, shared between single-item and bulk label printing
/// so both stay in sync with the same saved-printer list and behave identically.
struct PrinterPickerSection: View {
    @Binding var selectedPrinter: DiscoveredPrinter?
    @Binding var autoCut: Bool

    @ObservedObject private var printerManager = LabelPrinterManager.shared
    @ObservedObject private var diagnostics = PrinterSearchDiagnostics.shared
    @State private var availablePrinters: [DiscoveredPrinter] = []
    @State private var isDiscovering = false
    @State private var manualIP = ""
    @State private var showManualEntry = false
    @State private var searchFoundNothing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Printer")
                .font(.scaled(13, weight: .medium))
                .foregroundColor(.sMutedFG)

            HStack(spacing: 8) {
                ForEach(printerManager.services, id: \.displayName) { service in
                    let isSelected = printerManager.activeServiceName == service.displayName
                    Button {
                        printerManager.activeServiceName = service.displayName
                        selectedPrinter = nil
                        availablePrinters = []
                    } label: {
                        VStack(spacing: 3) {
                            Text(service.displayName)
                                .font(.scaled(13, weight: .medium))
                            if !service.isAvailable {
                                Text("Not set up")
                                    .font(.scaled(10))
                                    .foregroundColor(isSelected ? .sAccentFG.opacity(0.8) : .sMutedFG)
                            }
                        }
                        .foregroundColor(isSelected ? .sAccentFG : (service.isAvailable ? .sForeground : .sMutedFG))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.sAccent : Color.sCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color.sBorder, lineWidth: 0.5)
                        )
                        .cornerRadius(10)
                    }
                    .disabled(!service.isAvailable)
                }
            }

            if printerManager.activeService.isAvailable && printerManager.activeService.displayName != "AirPrint" {
                brotherPicker

                Toggle(isOn: $autoCut) {
                    Text("Auto cut after each label")
                        .font(.scaled(13))
                        .foregroundColor(.sForeground)
                }
                .tint(.sAccent)
            }
        }
        .onAppear {
            if selectedPrinter == nil {
                selectedPrinter = printerManager.savedPrinters.first
            }
        }
    }

    private var brotherPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedPrinter {
                HStack {
                    Image(systemName: "printer.fill")
                        .foregroundColor(.sAccent)
                    Text(selectedPrinter.name)
                        .font(.scaled(13))
                        .foregroundColor(.sForeground)
                    Spacer()
                    Button("Change") { self.selectedPrinter = nil }
                        .font(.scaled(12, weight: .medium))
                }
            } else {
                if !printerManager.savedPrinters.isEmpty {
                    Text("Recent printers")
                        .font(.scaled(11, weight: .medium))
                        .foregroundColor(.sMutedFG)
                    ForEach(printerManager.savedPrinters) { printer in
                        printerRow(printer)
                    }
                    Rectangle().fill(Color.sBorder).frame(height: 0.5).padding(.vertical, 2)
                }

                Button {
                    Task { await discoverPrinters() }
                } label: {
                    HStack(spacing: 6) {
                        if isDiscovering {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "wifi")
                        }
                        Text(isDiscovering ? "Searching..." : "Find printers")
                    }
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sAccent)
                }
                .disabled(isDiscovering)

                ForEach(availablePrinters) { printer in
                    printerRow(printer)
                }

                // A search that finds nothing looks identical to a search that was never
                // allowed to run. iOS gives no API to read Local Network permission, so
                // the most common cause gets named rather than leaving a silent dead end.
                if searchFoundNothing {
                    Text((diagnostics.lastMessage.isEmpty ? "No printers found." : diagnostics.lastMessage)
                         + " If the printer is on and on this Wi-Fi, check Settings › Privacy & Security › Local Network and make sure Invo Billing is allowed — without it iOS blocks the search silently.")
                        .font(.scaled(11))
                        .foregroundColor(Color(red: 0.851, green: 0.588, blue: 0.082))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Network search relies on the printer answering a Bonjour broadcast, which
                // it won't do in Wireless Direct mode or when its advertised record is stale.
                // Typing the address off the printer's own screen always works.
                if showManualEntry {
                    HStack(spacing: 8) {
                        TextField("192.168.1.13", text: $manualIP)
                            .font(.scaled(13))
                            .foregroundColor(.sForeground)
                            .tint(.sAccent)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.sBackground)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.sBorder, lineWidth: 0.5))
                            .cornerRadius(6)

                        Button("Use") {
                            let ip = manualIP.trimmingCharacters(in: .whitespaces)
                            guard !ip.isEmpty else { return }
                            let printer = DiscoveredPrinter(
                                id: ip, name: "Brother printer",
                                connectionType: "Wi-Fi", channelKind: "wifi"
                            )
                            selectedPrinter = printer
                            printerManager.remember(printer)
                        }
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sAccent)
                    }
                } else {
                    Button("Enter IP address") { showManualEntry = true }
                        .font(.scaled(12, weight: .medium))
                        .foregroundColor(.sMutedFG)
                }
            }
        }
        .padding(10)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(8)
    }

    private func printerRow(_ printer: DiscoveredPrinter) -> some View {
        Button {
            selectedPrinter = printer
            printerManager.remember(printer)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(printer.name)
                        .font(.scaled(13))
                        .foregroundColor(.sForeground)
                    // Two printers of the same model are otherwise indistinguishable in
                    // this list — the address is the only thing that tells them apart.
                    if !printer.id.isEmpty {
                        Text(printer.id)
                            .font(.scaled(10))
                            .foregroundColor(.sMutedFG)
                    }
                }
                Spacer()
                Text(printer.connectionType)
                    .font(.scaled(11))
                    .foregroundColor(.sMutedFG)
            }
        }
    }

    private func discoverPrinters() async {
        isDiscovering = true
        searchFoundNothing = false
        availablePrinters = await printerManager.activeService.discoverPrinters()
        isDiscovering = false
        searchFoundNothing = availablePrinters.isEmpty
    }
}
