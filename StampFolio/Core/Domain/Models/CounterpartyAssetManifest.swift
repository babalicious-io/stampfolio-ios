//
//  CounterpartyAssetManifest.swift
//  StampFolio
//
//  Model for the external JSON manifest some Counterparty assets point to via `description`
//

import Foundation

/// External JSON manifest referenced from a Counterparty `description` field.
/// Covers CIP-25 / TokenScan enhanced JSON (`image_large`, `image_large_hd`) and older
/// xcp.fun / rarepepedirectory schemas (`image`, typed `images[]`).
struct CounterpartyAssetManifest: Decodable {

    /// Top-level image URL string, when present
    let image: String?

    /// TokenScan / FAKEDUST enhanced large artwork
    let imageLarge: String?

    /// TokenScan / FAKEDUST enhanced HD artwork
    let imageLargeHd: String?

    /// Array of typed image entries (e.g. icon/standard/hires variants), when present
    let images: [ManifestImage]?

    struct ManifestImage: Decodable {
        let type: String?
        let data: String?
    }

    enum CodingKeys: String, CodingKey {
        case image
        case imageLarge = "image_large"
        case imageLargeHd = "image_large_hd"
        case images
    }

    /// Best artwork URL, large-first so fullscreen is not a 48×48 icon.
    /// Extra CIP-25 fields (`audio`, `video`, `html`) are ignored.
    var resolvedImageURLString: String? {
        if let imageLargeHd, !imageLargeHd.isEmpty { return imageLargeHd }
        if let imageLarge, !imageLarge.isEmpty { return imageLarge }
        if let hires = firstImageData(ofType: "hires") { return hires }
        if let large = firstImageData(ofType: "large") { return large }
        if let standard = firstImageData(ofType: "standard") { return standard }
        if let image, !image.isEmpty { return image }
        if let icon = firstImageData(ofType: "icon") { return icon }
        return images?.first(where: { $0.data != nil })?.data
    }

    private func firstImageData(ofType type: String) -> String? {
        images?.first { $0.type?.lowercased() == type }?.data
    }
}
