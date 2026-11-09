import Foundation
import Security

/// A Chinese update must carry the same signing certificate as the running copy.
enum BundleSignature {
    static func trustedHash(
        of bundleURL: URL, runningCertificate: Data? = runningLeaf()
    ) -> Data? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
            let staticCode,
            SecStaticCodeCheckValidity(staticCode, flags, nil) == errSecSuccess,
            let runningCertificate, let candidate = leaf(of: staticCode),
            runningCertificate == candidate
        else { return nil }
        return uniqueHash(of: staticCode)
    }

    /// An unsealed bundle can claim any identity, and a nested helper is where one hides.
    private static let flags = SecCSFlags(
        rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)

    private static func runningLeaf() -> Data? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return nil
        }
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

    private static func uniqueHash(of staticCode: SecStaticCode) -> Data? {
        var information: CFDictionary?
        let options = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, options, &information) == errSecSuccess
        else { return nil }
        return (information as? [String: Any])?[kSecCodeInfoUnique as String] as? Data
    }
}
