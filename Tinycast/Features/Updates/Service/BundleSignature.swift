import Foundation
import Security

/// Pins an update to the identity the running copy was signed with. Tinycast is self-signed and
/// never notarized, so a matching leaf certificate is the only integrity guarantee there is — and
/// that same match is what keeps the Accessibility grant alive across the swap.
enum BundleSignature {
    static func matchesRunningApp(_ bundleURL: URL) -> Bool {
        guard let running = runningLeaf(), let candidate = leaf(ofBundleAt: bundleURL) else {
            return false
        }
        return running == candidate
    }

    private static func runningLeaf() -> Data? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return nil
        }
        return leaf(of: staticCode)
    }

    private static func leaf(ofBundleAt bundleURL: URL) -> Data? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
            let staticCode
        else { return nil }
        // Check the seal before reading the certificate out of it: an unsealed bundle can claim
        // any identity, and a nested helper is exactly where a swapped binary would hide.
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        guard SecStaticCodeCheckValidity(staticCode, flags, nil) == errSecSuccess else { return nil }
        return leaf(of: staticCode)
    }

    private static func leaf(of code: SecStaticCode) -> Data? {
        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &information) == errSecSuccess,
            let dictionary = information as? [String: Any],
            let certificates = dictionary[kSecCodeInfoCertificates as String] as? [SecCertificate],
            let leaf = certificates.first
        else { return nil }
        return SecCertificateCopyData(leaf) as Data
    }
}
