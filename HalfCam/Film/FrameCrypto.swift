import CryptoKit
import Foundation
import Security

enum FrameCrypto {
    private static let service = "dev.halfcam.frame"
    private static let account = "aes-gcm"

    static func seal(_ plain: Data) -> Data? {
        guard let key = key() else { return nil }
        guard let box = try? AES.GCM.seal(plain, using: key), let combined = box.combined else { return nil }
        return combined
    }

    static func open(_ sealed: Data) -> Data? {
        if looksPlain(sealed) { return sealed }
        guard let key = key() else { return nil }
        guard let box = try? AES.GCM.SealedBox(combined: sealed) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }

    static func looksPlain(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let b = [UInt8](data.prefix(12))
        if b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 { return true }
        if b[0] == 0xFF && b[1] == 0xD8 { return true }
        if b[0] == 0x49 && b[1] == 0x49 && b[2] == 0x2A && b[3] == 0x00 { return true }
        if b[0] == 0x4D && b[1] == 0x4D && b[2] == 0x00 && b[3] == 0x2A { return true }
        if data.dropFirst(4).prefix(4).elementsEqual("ftyp".utf8) { return true }
        return false
    }

    private static func key() -> SymmetricKey? {
        if let stored = loadKey() { return SymmetricKey(data: stored) }
        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard status == errSecSuccess else { return nil }
        saveKey(bytes)
        return SymmetricKey(data: bytes)
    }

    private static func loadKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func saveKey(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
