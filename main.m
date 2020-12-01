//
//  main.m
//
//  Created by Milan Stute on 01.12.20.
//  Copyright © 2020 SEEMOO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "Sharing/SFAppleIDAccount.h"

void export_key(SFAppleIDAccount *account, NSString *path) {
    NSDictionary *query = @{(id)kSecClass: (id)kSecClassKey,
                            (id)kSecReturnRef: (id)kCFBooleanTrue,
                            (id)kSecValuePersistentRef: account.identity.privateKeyPersistentReference};
    CFTypeRef item;
    OSStatus res = SecItemCopyMatching((CFDictionaryRef)query, &item);
    if (res != 0) {
        NSLog(@"Failed to extract key: %@", SecCopyErrorMessageString(res, NULL));
    } else {
        CFDataRef data;
        SecItemImportExportKeyParameters params;
        memset(&params, 0, sizeof(params));
        params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
        params.flags = kSecKeySecurePassphrase;
        params.alertPrompt = (__bridge CFStringRef)@"Enter passphrase for private key";
        NSLog(@"Found key: %@", item);
        res = SecItemExport(item, kSecFormatWrappedOpenSSL, 0, &params, &data);
        if (res != 0) {
            NSLog(@"Failed to export key: %@", SecCopyErrorMessageString(res, NULL));
        } else {
            NSData *d = (__bridge NSData *)(data);
            [d writeToFile:path atomically:FALSE];
            NSLog(@"Exported key to '%@'", path);
        }
    }
}

NSData *get_certificate_data(NSData *persistentRef) {
    NSDictionary *query = @{(id)kSecClass: (id)kSecClassCertificate,
                            (id)kSecReturnRef: (id)kCFBooleanTrue,
                            (id)kSecValuePersistentRef: persistentRef};
    
    CFTypeRef item;
    OSStatus res = SecItemCopyMatching((CFDictionaryRef)query, &item);
    if (res != 0) {
        NSLog(@"Failed to extract certificate: %@", SecCopyErrorMessageString(res, NULL));
    } else {
        NSLog(@"Found certificate: %@", item);
        CFDataRef data;
        res = SecItemExport(item, kSecFormatPEMSequence, kSecItemPemArmour, NULL, &data);
        if (res != 0) {
            NSLog(@"Failed to export certificate: %@", SecCopyErrorMessageString(res, NULL));
        } else {
            return (__bridge NSData *)(data);
        }
    }
    return NULL;
}

void export_certificates(const SFAppleIDAccount *account, NSString *path) {
    NSData *intermediate_cert = get_certificate_data(account.identity.intermediateCertificatePersistentReference);
    
    NSData *cert = get_certificate_data(account.identity.certificatePersistentReference);
    
    if (intermediate_cert == NULL || cert == NULL) {
        NSLog(@"Failed to export certificates");
        return;
    }
    NSMutableData *certs = [NSMutableData dataWithLength:0];
    [certs appendData:cert];
    [certs appendData:intermediate_cert];
    
    [certs writeToFile:path atomically:FALSE];
    NSLog(@"Exported certificates to '%@'", path);
}

void export_validation_record(const SFAppleIDAccount *account, NSString *path) {
    [account.validationRecord.data writeToFile:path atomically:FALSE];
    NSLog(@"Exported validation record data to '%@'", path);
}

int main(int argc, const char * argv[]) {

    // as defined in sharingd`-[SDAppleIDDatabaseManager _readPrefs]
    NSData *plist = (__bridge NSData *) CFPreferencesCopyValue((CFStringRef)@"AppleIDAccount",
                                                               (CFStringRef)@"com.apple.sharingd",
                                                               (CFStringRef)kCFPreferencesCurrentUser,
                                                               (CFStringRef)kCFPreferencesCurrentHost);

    SFAppleIDAccount *account = [NSKeyedUnarchiver unarchivedObjectOfClass:SFAppleIDAccount.class fromData:plist error:NULL];
    
    // private key and certificate are stored in iCloud keychain
    // persistent reference seems to consist of SQLite table and 'rowid'
    //
    // example (privateKeyPersistentReference):
    // <63657274 00000000 00000002>
    //   c e r t                 ^
    //                         rowid
    
    export_validation_record(account, @"record_data.cms");
    
    export_certificates(account, @"certificate.pem");

    export_key(account, @"key.pem");
    
    return 0;
}
