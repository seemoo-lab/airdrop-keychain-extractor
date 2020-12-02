# Extracting Apple ID Validation Record, Certificate, and Key for AirDrop

This repository describes the process and provides the tools that allows extracting the cryptographic secrets used for Apple AirDrop's authentication protocol. The extracted secrets can be used in an open AirDrop implementation such as [OpenDrop](https://github.com/seemoo-lab/opendrop.git).
*This procedure should work at least for macOS 10.14, 10.15, and 11.0.*

**Warning:** This procedure requires to temporarily disable some of macOS' security features! Use at your own risk.

## Background

To understand the purpose of the Apple ID validation record, the certificate, and key, read our paper:

* Milan Stute, Sashank Narain, Alex Mariotto, Alexander Heinrich, David Kreitschmann, Guevara Noubir, and Matthias Hollick. **A Billion Open Interfaces for Eve and Mallory: MitM, DoS, and Tracking Attacks on iOS and macOS Through Apple Wireless Direct Link.** *28th USENIX Security Symposium (USENIX Security ’19)*, August 14–16, 2019, Santa Clara, CA, USA. [Link](https://www.usenix.org/conference/usenixsecurity19/presentation/stute)


## 1. Disable System Integrity Protection

We are using the Security framework to retrieve items from the system's keychain. To be successful, the querying binary needs to have the correct `keychain-access-group` in its entitlements, i.e., `com.apple.sharing.appleidauthentication`. Since this is an Apple-internal entitlement, we have to disable `amfid` that checks binary signatures and enforces the system's policies.

To do this, we first need to disable SIP via macOS' recovery mode. Restart your Mac and hold ⌘+R. In recovery mode, open the terminal and enter
```
csrutil enable --without nvram
```
and reboot the Mac. Then, add the following boot parameter via the Terminal
```
sudo nvram boot-args="amfi_get_out_of_my_way=1"
```
and reboot again.

To restore full SIP later, reboot in macOS' recovery mode (⌘+R) and run
```
nvram -d boot-args
csrutil enable
```

## 2. Build and run the extractor

We build and run the extraction utility (note that you need a developer certificate for this):
```
git clone https://github.com/seemoo-lab/airdrop-secret-extractor.git
cd airdrop-secret-extractor
make
./airdrop-secret-extractor
```
The program will ask you for a passphrase to store the key component on disk. You should now have three items in the current directory:

* `validation_record.cms`
* `certificate.pem`
* `key.pem`


## 3. Use with OpenDrop

Copy the three files into `~/.opendrop/keys`. When starting OpenDrop the next time, you will be asked to enter the passphrase for the key.

Your OpenDrop instance should now be discoverable as one of your devices (`receive`) and should be able to discover your devices that are in contacts-only mode (`find` and `send`).
