import UIKit

/// Opens a WhatsApp chat with a prefilled message.
///
/// Uses the `https://wa.me` universal link rather than `whatsapp://`: it opens the app
/// when installed and the web page otherwise, and needs no `LSApplicationQueriesSchemes`
/// entry — without one, `canOpenURL(whatsapp://)` always answers false and the button
/// silently does nothing.
enum WhatsApp {
    /// Indian numbers are stored without the country code; wa.me needs it.
    static func url(phone: String, message: String) -> URL? {
        var digits = phone.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("0") { digits.removeFirst() }
        guard !digits.isEmpty else { return nil }
        let full = digits.count == 10 ? "91\(digits)" : digits

        // `.urlQueryAllowed` leaves `&`, `+`, `=` and `#` unescaped, which cuts the message
        // short at a client called "Shah & Sons".
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        guard let text = message.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://wa.me/\(full)?text=\(text)")
    }

    @MainActor
    static func open(phone: String, message: String) {
        guard let url = url(phone: phone, message: message) else { return }
        UIApplication.shared.open(url)
    }
}
