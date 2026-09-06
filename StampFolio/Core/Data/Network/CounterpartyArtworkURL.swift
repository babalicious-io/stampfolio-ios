//
//  CounterpartyArtworkURL.swift
//  StampFolio
//
//  CIP-25 / TokenScan description classifier and ipfs:/ar:// HTTPS gateway rewrite
//

import Foundation

/// Classifies an on-chain Counterparty `description` and rewrites content-addressed
/// schemes to HTTPS gateways. Kingfisher and ATS only receive `https://` raster URLs.
enum CounterpartyArtworkURL {

    /// How the resolver should treat a description string
    enum Classification: Equatable {
        /// HTTPS URL that is already a raster image (by path extension or imgur shorthand)
        case directImage(URL)
        /// HTTPS URL to fetch as JSON manifest or image bytes
        case fetch(URL)
        /// Unusable as artwork (`stamp:`, `ord:`, media sites, plain text, HTTP-only)
        case skip
    }

    // MARK: - Public

    /// Classify a raw `description` value (CIP-25 formats, HTTP(S) URLs, or skip).
    static func classify(_ description: String) -> Classification {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .skip }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("stamp:") || lower.hasPrefix("ord:") { return .skip }
        if isExternalMediaPage(lower) { return .skip }

        if lower.hasPrefix("imgur/") {
            let rest = String(trimmed.dropFirst(6))
            let file = rest.split(separator: ";", maxSplits: 1).first.map(String.init) ?? rest
            guard !file.isEmpty, let url = URL(string: "https://i.imgur.com/\(file)") else {
                return .skip
            }
            return .directImage(url)
        }

        guard let rewritten = rewrittenHTTPSString(trimmed),
              let url = URL(string: rewritten) else {
            return .skip
        }

        if hasRasterExtension(url) {
            return .directImage(url)
        }
        return .fetch(url)
    }

    /// Rewrite `ipfs:` / `ar://` / CIP-25 hash suffixes to an HTTPS URL, or `nil` for HTTP/unusable.
    static func httpsURL(from raw: String) -> URL? {
        guard let rewritten = rewrittenHTTPSString(raw),
              let url = URL(string: rewritten),
              url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }

    /// MIME types Kingfisher can decode as raster artwork (not SVG).
    static func isRasterMIME(_ mimeType: String) -> Bool {
        let mime = mimeType.lowercased()
        return mime == "image/jpeg"
            || mime == "image/jpg"
            || mime == "image/png"
            || mime == "image/gif"
            || mime == "image/webp"
            || mime == "image/avif"
            || mime == "image/bmp"
    }

    /// Path-extension GIF check. Horizon proxy URLs often have no extension and stay static.
    static func isGIF(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "gif"
    }

    // MARK: - Gateway rewrite

    /// HTTPS string after stripping a CIP-25 `;hash` suffix and rewriting native ipfs/ar schemes.
    /// Already-HTTPS Arweave (`https://….ar.io/…`) and IPFS gateways are left unchanged.
    static func rewrittenHTTPSString(_ raw: String) -> String? {
        let trimmed = strippingCIP25Hash(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()

        if lower.hasPrefix("ipfs:") {
            var rest: String
            if lower.hasPrefix("ipfs://") {
                rest = String(trimmed.dropFirst(7))
            } else {
                rest = String(trimmed.dropFirst(5))
            }
            if rest.lowercased().hasPrefix("ipfs/") {
                rest = String(rest.dropFirst(5))
            }
            guard !rest.isEmpty else { return nil }
            return "https://ipfs.io/ipfs/\(rest)"
        }

        if lower.hasPrefix("ar://") {
            let rest = String(trimmed.dropFirst(5))
            guard !rest.isEmpty else { return nil }
            return "https://arweave.net/\(rest)"
        }

        if lower.hasPrefix("https://") {
            return trimmed
        }

        return nil
    }

    // MARK: - Private

    /// CIP-25 `https://host/file.json;sha256` — drop `;HASH` when the suffix has no `/`.
    private static func strippingCIP25Hash(_ raw: String) -> String {
        guard let separator = raw.lastIndex(of: ";") else { return raw }
        let suffix = raw[raw.index(after: separator)...]
        if suffix.isEmpty || suffix.contains("/") { return raw }
        return String(raw[..<separator])
    }

    private static func hasRasterExtension(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "gif", "jpg", "jpeg", "png", "webp", "avif", "bmp":
            return true
        default:
            return false
        }
    }

    private static func isExternalMediaPage(_ lowercased: String) -> Bool {
        lowercased.contains("soundcloud.com")
            || lowercased.contains("youtube.com")
            || lowercased.contains("youtu.be")
            || lowercased.contains("vimeo.com")
    }
}
