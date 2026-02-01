//
//  KeychainHelper.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.02.26.
//

import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let service = "com.blindside-studios.Relista"

    enum KeychainKey: String {
        case mistralAPIKey = "APIKeyMistral"
        case claudeAPIKey = "APIKeyClaude"
        case openRouterAPIKey = "APIKeyOpenRouter"
    }

    func save(_ value: String, for key: KeychainKey) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true,  // Enable iCloud Keychain sync
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save error for \(key.rawValue): \(status)")
        }
    }

    func get(_ key: KeychainKey) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return ""
    }

    func delete(_ key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: true
        ]

        SecItemDelete(query as CFDictionary)
    }

    // Convenience properties for direct access
    var mistralAPIKey: String {
        get { get(.mistralAPIKey) }
        set { save(newValue, for: .mistralAPIKey) }
    }

    var claudeAPIKey: String {
        get { get(.claudeAPIKey) }
        set { save(newValue, for: .claudeAPIKey) }
    }

    var openRouterAPIKey: String {
        get { get(.openRouterAPIKey) }
        set { save(newValue, for: .openRouterAPIKey) }
    }
}
