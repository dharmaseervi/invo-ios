//
//  AppEnvironment.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/30/25.
//

enum AppEnvironment {
    static let baseURL: String = {
#if DEBUG
#if targetEnvironment(simulator)
        return "http://localhost:8080/api/v1"       // Simulator shares the Mac's localhost
#else
        return "http://192.168.1.4:8080/api/v1"     // Physical device — Mac's LAN IP, same Wi-Fi required
#endif
#else
        return "https://invobilling.com/api/v1" // ← production for release
#endif
    }()
}
