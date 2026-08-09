//
//  KeychainSecureStore.swift
//  hosmas
//
//  The Apple half of HosKhas's SecureStore. Android supplies a Keystore-backed
//  equivalent; the package sees neither.
//

import Foundation
import Security
import HosKhas

struct KeychainSecureStore: SecureStore {
    let service: String

    init(service: String = "in.hosmas.hoskhas") {
        self.service = service
    }

    enum KeychainError: Error {
        case status(OSStatus)
    }

    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess {
            HKLog.trace("keychain", "updated \(key) (\(data.count) bytes)")
            return
        }
        guard updated == errSecItemNotFound else {
            HKLog.error("keychain", "update \(key) failed: OSStatus \(updated)")
            throw KeychainError.status(updated)
        }

        let added = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        guard added == errSecSuccess else {
            HKLog.error("keychain", "add \(key) failed: OSStatus \(added)")
            throw KeychainError.status(added)
        }
        HKLog.trace("keychain", "stored \(key) (\(data.count) bytes)")
    }

    func load(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            HKLog.trace("keychain", "no entry for \(key)")
            return nil
        }
        guard status == errSecSuccess else {
            HKLog.error("keychain", "load \(key) failed: OSStatus \(status)")
            throw KeychainError.status(status)
        }
        return result as? Data
    }

    func remove(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }
}
