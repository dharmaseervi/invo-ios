//
//  AppEnvironment.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/30/25.
//

enum AppEnvironment {
    static let baseURL: String = {
#if DEBUG
        return "http://localhost:8080/api/v1"  // ← local for development
#else
        return "https://invobilling.com/api/v1" // ← production for release
#endif
    }()
}
