import Foundation

/// Text cells are always quoted and formula-like values are prefixed with an
/// apostrophe. Numeric cells should be serialized separately to retain their type.
enum SafeCSV {
    static func text(_ value: String) -> String {
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        let unsafe = first.map { "=+-@".contains($0) } ?? false
        let escaped = (unsafe ? "'" + value : value).replacingOccurrences(of: "\"", with: "\"\"")
        return "\"" + escaped + "\""
    }

    static func write(_ csv: String, filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(filename)
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(contentsOf: csv.utf8)
        try data.write(to: url, options: .atomic)
        return url
    }
}
