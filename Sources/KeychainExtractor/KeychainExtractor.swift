//
//  KeychainExtractor.swift
//
//
//  Created by Kyle on 2023/5/3.
//

import Foundation
import os.log
import Security
import Sharing

@main
enum KeychainExtractor {
    static let logger = Logger(subsystem: "KeychainExtractor", category: "KeychainExtractor")

    static func main() throws {
        // as defined in sharingd`-[SDAppleIDDatabaseManager _readPrefs]
        guard let list = CFPreferencesCopyValue("AppleIDAccount" as CFString, "com.apple.sharingd" as CFString, kCFPreferencesCurrentUser as CFString, kCFPreferencesCurrentHost as CFString),
              let nsData = list as? NSData else {
            return
        }
        let data = Data(nsData)
        guard let account = try NSKeyedUnarchiver.unarchivedObject(ofClass: SFAppleIDAccount.self, from: data) else {
            return
        }
        // private key and certificate are stored in iCloud keychain
        // persistent reference seems to consist of SQLite table and 'rowid'
        //
        // example (privateKeyPersistentReference):
        // <63657274 00000000 00000002>
        //   c e r t                 ^
        //                         rowid
        exportValidationRecord(account: account, path: "validation_record.cms")
        exportCertificates(account: account, path: "certificate.pem")
        exportKey(account: account, path: "key.pem")
    }
    
    static func exportValidationRecord(account: SFAppleIDAccount, path: String) {
        (account.validationRecord.data as NSData).write(toFile: path, atomically: false)
        logger.info("Exported validation record data to \(path, privacy: .public)")
    }

    static func exportCertificates(account: SFAppleIDAccount, path: String) {
        func getCertificateData(persistentRef: Data) -> Data? {
            let query: NSDictionary = [
                kSecClass: kSecClassCertificate,
                kSecReturnRef: kCFBooleanTrue as Any,
                kSecValuePersistentRef: persistentRef,
            ]
            var item: CFTypeRef?
            let res = SecItemCopyMatching(query, &item)
            guard res == 0 else {
                logger.error("Failed to extract certificate: \(SecCopyErrorMessageString(res, nil))")
                return nil
            }

            guard let item else {
                logger.error("Failed to get item")
                return nil
            }
            logger.info("Found certificate: \(item.debugDescription)")
            var data: CFData?
            let exportResult = SecItemExport(item, .formatPEMSequence, .pemArmour, nil, &data)
            guard exportResult == 0 else {
                logger.error("Failed to export certificate: \(SecCopyErrorMessageString(exportResult, nil))")
                return nil
            }
            guard let data else {
                logger.error("Failed to get data in key")
                return nil
            }
            return Data(data as NSData)
        }
        let intermediateCert = getCertificateData(persistentRef: account.identity.intermediateCertificatePersistentReference)
        let cert = getCertificateData(persistentRef: account.identity.certificatePersistentReference)
        guard let intermediateCert, let cert else {
            logger.error("Failed to export certificates")
            return
        }
        var certs = Data()
        certs.append(cert)
        certs.append(intermediateCert)
        (certs as NSData).write(toFile: path, atomically: false)
        logger.info("Exported certificates to \(path, privacy: .public)")
    }

    static func exportKey(account: SFAppleIDAccount, path: String) {
        let query: NSDictionary = [
            kSecClass: kSecClassKey,
            kSecReturnRef: kCFBooleanTrue as Any,
            kSecValuePersistentRef: account.identity.privateKeyPersistentReference as Any,
        ]
        var item: CFTypeRef?
        let res = SecItemCopyMatching(query, &item)
        guard res == 0 else {
            logger.error("Failed to extract key: \(SecCopyErrorMessageString(res, nil))")
            return
        }

        guard let item else {
            logger.error("Failed to get item")
            return
        }
        logger.info("Found key: \(item.debugDescription)")

        var params: SecItemImportExportKeyParameters!
        memset(&params, 0, MemoryLayout<SecItemImportExportKeyParameters>.stride)
        params.version = UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION)
        params.flags = .securePassphrase
        params.alertPrompt = Unmanaged.passRetained(NSString(string: "Enter passphrase for private key"))
        var data: CFData?
        let exportResult = SecItemExport(item, .formatOpenSSL, [], &params, &data)
        guard exportResult == 0 else {
            logger.error("Failed to export key: \(SecCopyErrorMessageString(exportResult, nil))")
            return
        }
        guard let data else {
            logger.error("Failed to get data in key")
            return
        }
        (data as NSData).write(toFile: path, atomically: false)
        logger.info("Exported key to \(path, privacy: .public)")
    }
}
