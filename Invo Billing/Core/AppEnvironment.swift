//
//  AppEnvironment.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/30/25.
//

import Foundation

enum AppEnvironment {
    static let baseURL: String = {
#if DEBUG
        // A debug build can be pointed anywhere with -apiBase, which matters because
        // the port a local server happens to be on is not always 8080 — and because a
        // server on 8080 may be one connected to the production database, which a test
        // run must never write to. Release ignores this entirely.
        //
        //   xcrun simctl launch <device> com.invobilling.app -apiBase http://localhost:8090/api/v1
        if let override = UserDefaults.standard.string(forKey: "apiBase"),
           override.hasPrefix("http") {
            return override
        }
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
