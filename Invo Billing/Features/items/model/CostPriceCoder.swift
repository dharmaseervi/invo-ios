import Foundation

/// Encodes a cost price into a letter code so it can be printed on a shelf/product
/// label for staff reference without customers being able to read the actual cost.
/// Classic retail technique — e.g. 1250 -> "ADPZ".
enum CostPriceCoder {
    static let digitMap: [Character: String] = [
        "1": "A", "2": "D", "3": "T", "4": "C", "5": "P",
        "6": "SH", "7": "S", "8": "E", "9": "N", "0": "Z",
    ]

    static func encode(_ price: Double) -> String {
        let rounded = Int(price.rounded())
        return String(rounded).compactMap { digitMap[$0] }.joined()
    }
}
