//
//  BitcoinAddressValidator.swift
//  StampFolio
//
//  Bitcoin address validation (format and checksum)
//

import Foundation

/// Validates Bitcoin addresses (all formats supported by Stampchain)
struct BitcoinAddressValidator {
    
    // MARK: - Public Methods
    
    /// Validate a Bitcoin address
    /// - Parameter address: The address to validate
    /// - Returns: True if the address is valid
    func isValid(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return false }
        
        // Check address type and validate accordingly
        if trimmed.hasPrefix("1") {
            return isValidLegacyAddress(trimmed)
        } else if trimmed.hasPrefix("3") {
            return isValidP2SHAddress(trimmed)
        } else if trimmed.lowercased().hasPrefix("bc1q") {
            return isValidBech32Address(trimmed)
        } else if trimmed.lowercased().hasPrefix("bc1p") {
            return isValidBech32mAddress(trimmed)
        }
        
        return false
    }
    
    /// Get validation error message for an address
    /// - Parameter address: The address to validate
    /// - Returns: Error message or nil if valid
    func validationError(for address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return "Address cannot be empty"
        }
        
        // Check if it looks like a Bitcoin address
        let validPrefixes = ["1", "3", "bc1q", "bc1p", "BC1Q", "BC1P"]
        let hasValidPrefix = validPrefixes.contains { trimmed.hasPrefix($0) }
        
        guard hasValidPrefix else {
            return "Invalid Bitcoin address prefix"
        }
        
        if !isValid(trimmed) {
            if trimmed.hasPrefix("1") || trimmed.hasPrefix("3") {
                return "Invalid address checksum"
            } else {
                return "Invalid Bech32 address format"
            }
        }
        
        return nil
    }
    
    // MARK: - Legacy Address Validation (P2PKH)
    
    private func isValidLegacyAddress(_ address: String) -> Bool {
        // P2PKH addresses start with '1' and are 25-34 characters
        guard address.count >= 25 && address.count <= 34 else { return false }
        
        // Validate Base58Check encoding
        return validateBase58Check(address)
    }
    
    // MARK: - P2SH Address Validation
    
    private func isValidP2SHAddress(_ address: String) -> Bool {
        // P2SH addresses start with '3' and are 25-34 characters
        guard address.count >= 25 && address.count <= 34 else { return false }
        
        // Validate Base58Check encoding
        return validateBase58Check(address)
    }
    
    // MARK: - Bech32 Address Validation (Native SegWit)
    
    private func isValidBech32Address(_ address: String) -> Bool {
        let lowercased = address.lowercased()
        
        // bc1q addresses are 42 or 62 characters for P2WPKH or P2WSH
        guard lowercased.count == 42 || lowercased.count == 62 else { return false }
        
        return validateBech32(lowercased, variant: .bech32)
    }
    
    // MARK: - Bech32m Address Validation (Taproot)
    
    private func isValidBech32mAddress(_ address: String) -> Bool {
        let lowercased = address.lowercased()
        
        // bc1p addresses are 62 characters for P2TR
        guard lowercased.count == 62 else { return false }
        
        return validateBech32(lowercased, variant: .bech32m)
    }
    
    // MARK: - Base58Check Validation
    
    private func validateBase58Check(_ address: String) -> Bool {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        
        // Check all characters are in Base58 alphabet
        for char in address {
            guard alphabet.contains(char) else { return false }
        }
        
        // Decode Base58
        var result: [UInt8] = []
        for char in address {
            guard let index = alphabet.firstIndex(of: char) else { return false }
            let value = alphabet.distance(from: alphabet.startIndex, to: index)
            
            var carry = value
            for i in (0..<result.count).reversed() {
                carry += 58 * Int(result[i])
                result[i] = UInt8(carry % 256)
                carry /= 256
            }
            
            while carry > 0 {
                result.insert(UInt8(carry % 256), at: 0)
                carry /= 256
            }
        }
        
        // Add leading zeros
        for char in address {
            if char == "1" {
                result.insert(0, at: 0)
            } else {
                break
            }
        }
        
        // Check minimum length (1 byte version + 20 bytes hash + 4 bytes checksum)
        guard result.count >= 25 else { return false }
        
        // Verify checksum (last 4 bytes)
        let payload = Array(result.dropLast(4))
        let checksum = Array(result.suffix(4))
        
        let hash1 = sha256(Data(payload))
        let hash2 = sha256(hash1)
        let calculatedChecksum = Array(hash2.prefix(4))
        
        return checksum == calculatedChecksum
    }
    
    // MARK: - Bech32/Bech32m Validation
    
    private enum Bech32Variant {
        case bech32
        case bech32m
        
        var constant: Int {
            switch self {
            case .bech32: return 1
            case .bech32m: return 0x2bc830a3
            }
        }
    }
    
    private func validateBech32(_ address: String, variant: Bech32Variant) -> Bool {
        let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
        
        // Find separator
        guard let separatorIndex = address.lastIndex(of: "1") else { return false }
        
        let hrp = String(address[..<separatorIndex])
        let dataString = String(address[address.index(after: separatorIndex)...])
        
        // HRP must be "bc" for mainnet
        guard hrp == "bc" else { return false }
        
        // Data must be at least 6 characters (checksum)
        guard dataString.count >= 6 else { return false }
        
        // Decode data
        var data: [Int] = []
        for char in dataString {
            guard let index = charset.firstIndex(of: char) else { return false }
            data.append(charset.distance(from: charset.startIndex, to: index))
        }
        
        // Verify checksum
        return bech32VerifyChecksum(hrp: hrp, data: data, variant: variant)
    }
    
    private func bech32VerifyChecksum(hrp: String, data: [Int], variant: Bech32Variant) -> Bool {
        var values = bech32HrpExpand(hrp) + data
        return bech32Polymod(&values) == variant.constant
    }
    
    private func bech32HrpExpand(_ hrp: String) -> [Int] {
        var result: [Int] = []
        for char in hrp {
            result.append(Int(char.asciiValue! >> 5))
        }
        result.append(0)
        for char in hrp {
            result.append(Int(char.asciiValue! & 31))
        }
        return result
    }
    
    private func bech32Polymod(_ values: inout [Int]) -> Int {
        let generator = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
        var chk = 1
        
        for value in values {
            let top = chk >> 25
            chk = (chk & 0x1ffffff) << 5 ^ value
            for i in 0..<5 {
                if (top >> i) & 1 == 1 {
                    chk ^= generator[i]
                }
            }
        }
        
        return chk
    }
    
    // MARK: - SHA256 Helper
    
    private func sha256(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
}

// MARK: - CommonCrypto Import

import CommonCrypto
