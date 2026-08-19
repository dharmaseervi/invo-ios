//
//  KeychainManager.swift
//  invo
//
//  Created by dharmaseervi on 11/15/25.
//

import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    private let service = Bundle.main.bundleIdentifier ?? "invo"
    
    private func makeQuery(forKey key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
    
    func save(_ value: String, for key: String) -> Bool {
        let data = Data(value.utf8)
        var query = makeQuery(forKey: key)
        // if exists -> update, else add
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let attrs: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            return status == errSecSuccess
        } else {
            query[kSecValueData as String] = data
            let status = SecItemAdd(query as CFDictionary, nil)
            return status == errSecSuccess
        }
    }
    
    func load(_ key: String) -> String? {
        var query = makeQuery(forKey: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let s = String(data: data, encoding: .utf8) else {
            return nil
        }
        return s
    }
    
    func delete(_ key: String) -> Bool {
        let query = makeQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // Convenience keys
    private let tokenKey = "auth_token"
    func saveToken(_ token: String) -> Bool { save(token, for: tokenKey) }
    func loadToken() -> String? { load(tokenKey) }
    func deleteToken() -> Bool { delete(tokenKey) }
}
