import Combine
import UIKit

/// A discoverable label printer, regardless of which backend (AirPrint, Brother SDK) found it.
struct DiscoveredPrinter: Identifiable, Hashable, Codable {
    let id: String              // Brother: the channel's IP/serial/local-name; AirPrint: unused
    let name: String
    let connectionType: String  // "Bluetooth", "Wi-Fi", "AirPrint", etc. — shown in the UI
    var channelKind: String = "" // Brother-internal: "wifi" | "bluetoothMFi" | "ble" — picks how to reconnect
}

/// One printing backend. AirPrint and Brother's SDK both conform to this, so the rest
/// of the app (PrintLabelScreen) never needs to know which one is actually in use.
protocol LabelPrinterService {
    var displayName: String { get }
    /// Whether this backend can be used at all right now (e.g. Brother's SDK is linked
    /// and its runtime is ready — not whether a printer has actually been found yet).
    var isAvailable: Bool { get }

    func discoverPrinters() async -> [DiscoveredPrinter]
    func print(images: [UIImage], jobName: String, printer: DiscoveredPrinter?, autoCut: Bool) async throws
}

enum LabelPrinterError: LocalizedError {
    case notAvailable
    case noPrinterSelected
    case printFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "This printer backend isn't set up yet."
        case .noPrinterSelected: return "Select a printer first."
        case .printFailed(let reason): return "Print failed: \(reason)"
        }
    }
}

// MARK: - AirPrint (current default — works today, no extra SDK needed)

/// Wraps the existing UIPrintInteractionController flow. AirPrint does its own printer
/// discovery inside the system print sheet, so `discoverPrinters()` is a no-op here.
final class AirPrintLabelPrinterService: LabelPrinterService {
    let displayName = "AirPrint"
    let isAvailable = true

    func discoverPrinters() async -> [DiscoveredPrinter] { [] }

    func print(images: [UIImage], jobName: String, printer: DiscoveredPrinter?, autoCut: Bool) async throws {
        // AirPrint has no concept of a per-label auto-cut setting — that's controlled by
        // whatever driver/queue the AirPrint-connected printer itself exposes.
        PrintManager.printImages(images, jobName: jobName)
    }
}

// MARK: - Brother SDK

/// Brother's "Print SDK for iOS" ships as the `BRLMPrinterKit` framework. Add it to the
/// Xcode project (drag in the .xcframework Brother provides) and this file compiles in
/// automatically — nothing else in the app needs to change, since PrintLabelScreen only
/// talks to the `LabelPrinterService` protocol.
///
/// The calls below were verified against Brother's own "Print SDK Demo" sample app
/// (bundled with the SDK download, see NetPrinterSearcher.swift, PrinterConnectUtil.swift,
/// PrintImageFacade.swift, QLModelPrintSettings.swift in their Source/Model folder) —
/// not guessed. This block is gated on `canImport(BRLMPrinterKit)` so the app builds fine
/// even before the SDK is linked, with Brother simply reporting as unavailable.
#if canImport(BRLMPrinterKit)
import BRLMPrinterKit

/// Guards the SDK's single process-wide network search so only one runs at a time.
/// Carries the reason a search returned nothing, so an empty list can explain itself
/// instead of looking identical to a search that was never allowed to run.
@MainActor
final class PrinterSearchDiagnostics: ObservableObject {
    static let shared = PrinterSearchDiagnostics()
    @Published var lastMessage: String = ""
}

private actor NetworkSearchGate {
    static let shared = NetworkSearchGate()
    private var heldSince: Date?

    /// Longer than any search can legitimately run. A hold older than this means the
    /// waiter died without releasing, and refusing to break it would wedge every later
    /// search for the life of the app — the exact failure this gate exists to prevent.
    private static let staleAfter: TimeInterval = 30

    func acquire() async {
        while let since = heldSince, Date().timeIntervalSince(since) < Self.staleAfter {
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        heldSince = Date()
    }

    func release() {
        heldSince = nil
    }
}

final class BrotherLabelPrinterService: LabelPrinterService {
    let displayName = "Brother printer"
    var isAvailable: Bool { true }

    init() {
        // Backgrounding the app suspends an in-flight search without ending it, which
        // leaves the SDK believing a search is still running for the rest of the app's
        // life — every later search and connection then fails until a full relaunch.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: nil
        ) { _ in
            BRLMPrinterSearcher.cancelNetworkSearch()
        }
    }

    /// Set this to whichever Brother label printer model you actually own — it determines
    /// which print-settings defaults get used. Full list of supported models is in
    /// Brother's sample app's PrinterModel.swift (QL/PT/TD/RJ/PJ/MW series).
    var printerModel: BRLMPrinterModel = .QL_820NWB

    /// `BRLMNetworkSearchOption.printerList` isn't just an optional filter — Brother's own
    /// sample app always populates it, and leaving it empty returns zero results even when
    /// a printer is reachable. This is every model from their PrinterModel.swift, in the
    /// "Brother <model>" format their search expects (verified against the sample's
    /// `searchModelName` — `"Brother " + rawValue`, with "_203"/"_300" suffixes stripped).
    private static let allSearchModelNames: [String] = [
        "PJ-673", "PJ-763", "PJ-773", "MW-145MFi", "MW-260MFi", "MW-170", "MW-270",
        "RJ-4030Ai", "RJ-4040", "RJ-3050", "RJ-3150", "RJ-3050Ai", "RJ-3150Ai", "RJ-2050",
        "RJ-2140", "RJ-2150", "RJ-4230B", "RJ-4250WB", "TD-2120N", "TD-2130N", "TD-4100N",
        "TD-4420DN", "TD-4520DN", "TD-4550DNWB", "QL-710W", "QL-720NW", "QL-810W",
        "QL-820NWB", "QL-1110NWB", "QL-1115NWB", "PT-E550W", "PT-P750W", "PT-D800W",
        "PT-E800W", "PT-E850TKW", "PT-P900W", "PT-P950NW", "PT-P300BT", "PT-P710BT",
        "PT-P715eBT", "PT-P910BT", "RJ-3230B", "RJ-3250WB", "PT-D410", "PT-D460BT",
        "PT-D610BT", "PJ-822", "PJ-823", "PJ-862", "PJ-863", "PJ-883", "TD-2030A",
        "TD-2125N", "TD-2125NWB", "TD-2135N", "TD-2135NWB", "PT-E310BT", "PT-E510",
        "PT-E560BT", "TD-2310D", "TD-2320D", "TD-2320DF", "TD-2320DSA", "TD-2350D",
        "TD-2350DF", "TD-2350DSA", "TD-2350DFSA", "PT-N25BT", "PT-P300BTz", "TD-4415D",
        "TD-4425DN", "TD-4525DN", "TD-4455DNWB", "TD-4555DNWB", "TD-4425DNF",
        "TD-4555DNWBF", "RJ-3235B", "RJ-3255WB", "RJ-4235B", "RJ-4255WB", "PT-E720BT",
        "PT-E920BT",
    ].map { "Brother \($0)" }

    func discoverPrinters() async -> [DiscoveredPrinter] {
        // Run sequentially, never concurrently. BRLMPrinterSearcher is class-level global
        // state, and Brother's own sample only ever has one search alive at a time —
        // overlapping a Bluetooth search with the network one can make both return nothing.
        let wifi = await discoverWiFiPrinters()
        let bluetooth = await discoverBluetoothPrinters()
        // The SDK's search callback fires once per announcement, so the same printer can
        // come back repeatedly — dropping exact repeats keeps one machine to one row.
        var seen = Set<String>()
        return (wifi + bluetooth).filter { seen.insert("\($0.channelKind)|\($0.id)").inserted }
    }

    private func discoverWiFiPrinters() async -> [DiscoveredPrinter] {
        // BRLMPrinterSearcher's network search is process-wide class state: there is only
        // ever one, and starting a second while one is live makes both come back empty.
        // Serializing here is what stops a print-retry search and a "Find printers" tap
        // from wedging each other.
        await NetworkSearchGate.shared.acquire()
        let result = await runWiFiSearch()
        await NetworkSearchGate.shared.release()
        return result
    }

    private func runWiFiSearch() async -> [DiscoveredPrinter] {
        // No cancel before starting: cancelNetworkSearch() is the SDK's stop signal, and
        // firing it around a search that is about to begin suppresses that search's own
        // results. Brother's sample only ever calls it to abort a search in progress.
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var found: [DiscoveredPrinter] = []
                let lock = NSLock()

                func add(_ channel: BRLMChannel) {
                    let modelName = channel.extraInfo?.value(forKey: BRLMChannelExtraInfoKeyModelName) as? String ?? "Brother printer"
                    let printer = DiscoveredPrinter(
                        id: channel.channelInfo,
                        name: modelName,
                        connectionType: "Wi-Fi",
                        channelKind: "wifi"
                    )
                    lock.lock()
                    if !found.contains(where: { $0.id == printer.id }) { found.append(printer) }
                    lock.unlock()
                }

                let option = BRLMNetworkSearchOption()
                option.searchDuration = 15
                option.printerList = Self.allSearchModelNames

                let searcher = BRLMPrinterSearcher.startNetworkSearch(option) { channel in
                    add(channel)
                }

                // The result carries its own channel list. Relying on the callback alone
                // reports "no printers" whenever it doesn't fire, even though the search
                // itself succeeded — so both sources are merged.
                searcher.channels.forEach(add)

                let code = searcher.error.code
                let diagnostic: String
                switch code {
                case .noError: diagnostic = found.isEmpty ? "Search completed but no printer answered." : ""
                case .alreadySearching: diagnostic = "A previous search is still running."
                case .canceled: diagnostic = "Search was cancelled."
                case .unsupported: diagnostic = "Search is unsupported on this device."
                default: diagnostic = "Search failed (code \(code.rawValue))."
                }
                Task { @MainActor in PrinterSearchDiagnostics.shared.lastMessage = diagnostic }

                lock.lock()
                let result = found
                lock.unlock()
                continuation.resume(returning: result)
            }
        }
    }

    private func discoverBluetoothPrinters() async -> [DiscoveredPrinter] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let searcher = BRLMPrinterSearcher.startBluetoothSearch()
                let found = searcher.channels.map { channel in
                    DiscoveredPrinter(
                        id: channel.channelInfo,
                        name: channel.extraInfo?.value(forKey: BRLMChannelExtraInfoKeyModelName) as? String ?? "Brother printer",
                        connectionType: "Bluetooth",
                        channelKind: "bluetoothMFi"
                    )
                }
                continuation.resume(returning: found)
            }
        }
    }

    private func makeChannel(for printer: DiscoveredPrinter) -> BRLMChannel? {
        switch printer.channelKind {
        case "wifi": return BRLMChannel(wifiIPAddress: printer.id)
        case "bluetoothMFi": return BRLMChannel(bluetoothSerialNumber: printer.id)
        case "ble": return BRLMChannel(bleLocalName: printer.id)
        default: return nil
        }
    }

    /// Returns the opened driver, or the SDK's own reason for failing. That reason is
    /// what distinguishes "printer asleep" from "wrong address" from "already printing",
    /// so it gets surfaced instead of being collapsed into one generic message.
    private func openDriver(for printer: DiscoveredPrinter) -> (driver: BRLMPrinterDriver?, reason: String) {
        guard let channel = makeChannel(for: printer) else {
            return (nil, "unsupported connection type")
        }
        let result = BRLMPrinterDriverGenerator.open(channel)
        guard result.error.code == .noError, let driver = result.driver else {
            return (nil, String(describing: result.error.code))
        }
        return (driver, "")
    }

    func print(images: [UIImage], jobName: String, printer: DiscoveredPrinter?, autoCut: Bool) async throws {
        guard let printer else { throw LabelPrinterError.noPrinterSelected }

        var attempt = openDriver(for: printer)
        var searchNote = ""

        // A Wi-Fi printer's address is a DHCP lease, not an identity: it changes whenever
        // the printer or router restarts, and the saved entry then points at nothing. Look
        // the same model up again and retry once before declaring it unreachable.
        if attempt.driver == nil, printer.channelKind == "wifi" {
            let found = await discoverPrinters().filter { $0.channelKind == "wifi" && $0.id != printer.id }

            // A single printer can answer at more than one address at the same time —
            // its normal Wi-Fi address and its Wireless Direct one — and only the address
            // on the phone's current network will open. So every address this model
            // answered on gets tried, not just the first: with one printer on the shelf,
            // picking any row should end up printing.
            for candidate in found where candidate.name == printer.name {
                attempt = openDriver(for: candidate)
                if attempt.driver != nil {
                    await MainActor.run { LabelPrinterManager.shared.remember(candidate) }
                    break
                }
            }

            if attempt.driver == nil {
                searchNote = found.isEmpty
                    ? " No Brother printer answered a network search either."
                    : " Also tried " + found.map { $0.id }.joined(separator: ", ") + "."
            }
        }

        guard let driver = attempt.driver else {
            throw LabelPrinterError.printFailed(
                "Couldn't reach \(printer.name) at \(printer.id) — \(attempt.reason)."
                + searchNote
                + " Check the printer is on and on the same Wi-Fi as this iPhone, or enter its IP address manually."
            )
        }
        defer { driver.closeChannel() }

        guard let settings = BRLMQLPrintSettings(defaultPrintSettingsWith: printerModel) else {
            throw LabelPrinterError.printFailed("Unsupported printer model")
        }
        // `images` already contains one entry per requested copy (PrintLabelScreen builds
        // it that way for AirPrint's sake), so numCopies stays 1 here — otherwise copies
        // would multiply (quantity × quantity) instead of adding up correctly.
        settings.numCopies = 1
        settings.autoCut = autoCut
        settings.cutAtEnd = autoCut
        // Our rendered label image's pixel dimensions are an internal detail, not
        // literal millimeters — force the driver to scale the whole image to fit
        // whatever paper is actually loaded, so nothing at the bottom (price/ID/cost
        // code) can ever end up cropped off outside the physical printable area.
        settings.scaleMode = .fitPaperAspect

        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let result = driver.printImage(with: cgImage, settings: settings)
            if result.code != .noError {
                // `.name`-style descriptions in Brother's sample come from a helper class
                // (EnumToString.swift) that isn't part of the SDK itself — falling back to
                // the raw enum description here instead of reproducing that whole table.
                throw LabelPrinterError.printFailed(String(describing: result.code))
            }
        }
    }
}
#else
/// Placeholder shown until BRLMPrinterKit is added to the project — keeps the printer
/// picker in PrintLabelScreen functional (shows Brother as an option, clearly disabled)
/// instead of the option disappearing outright.
final class BrotherLabelPrinterService: LabelPrinterService {
    let displayName = "Brother printer"
    let isAvailable = false

    func discoverPrinters() async -> [DiscoveredPrinter] { [] }

    func print(images: [UIImage], jobName: String, printer: DiscoveredPrinter?, autoCut: Bool) async throws {
        throw LabelPrinterError.notAvailable
    }
}
#endif

// MARK: - Active backend selection

/// Remembers which printer backend the user last picked, so PrintLabelScreen doesn't
/// need to ask every time.
@MainActor
final class LabelPrinterManager: ObservableObject {
    static let shared = LabelPrinterManager()

    let services: [LabelPrinterService] = [
        AirPrintLabelPrinterService(),
        BrotherLabelPrinterService(),
    ]

    @Published var activeServiceName: String {
        didSet { UserDefaults.standard.set(activeServiceName, forKey: Self.backendKey) }
    }

    /// Printers actually used before, most-recent first — so printing a label for a
    /// different product (or switching between several printers you own) doesn't require
    /// re-discovering and re-picking every time. Capped so this doesn't grow forever.
    @Published var savedPrinters: [DiscoveredPrinter] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(savedPrinters) {
                UserDefaults.standard.set(data, forKey: Self.printerKey)
            }
        }
    }

    private static let maxSavedPrinters = 6
    private static let backendKey = "label_printer_backend"
    private static let printerKey = "label_printer_saved_printers"

    private init() {
        activeServiceName = UserDefaults.standard.string(forKey: Self.backendKey) ?? "AirPrint"
        if let data = UserDefaults.standard.data(forKey: Self.printerKey) {
            savedPrinters = (try? JSONDecoder().decode([DiscoveredPrinter].self, from: data)) ?? []
        }
    }

    var activeService: LabelPrinterService {
        services.first(where: { $0.displayName == activeServiceName }) ?? services[0]
    }

    /// Moves this printer to the front of the saved list (or adds it), so the most
    /// recently used printer is always the default suggestion.
    func remember(_ printer: DiscoveredPrinter) {
        // Matched on model + connection rather than address, because a Wi-Fi printer's IP
        // changes on its own — keying on it left a dead duplicate row for the same machine.
        var list = savedPrinters.filter { $0.name != printer.name || $0.channelKind != printer.channelKind }
        list.insert(printer, at: 0)
        if list.count > Self.maxSavedPrinters { list.removeLast(list.count - Self.maxSavedPrinters) }
        savedPrinters = list
    }
}
