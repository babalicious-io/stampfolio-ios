//
//  CounterpartyAssetManifest.swift
//  StampFolio
//
//  Model for the external JSON manifest some Counterparty assets point to via `description`
//

import Foundation

/// External JSON manifest that some Counterparty assets reference via their `description` field
/// (e.g. `description: "https://xcp.fun/XCPIANS.json"`). Covers the two schemas observed in the wild:
/// - xcp.fun style: top-level `image` and/or an `images` array with typed entries
/// - rarepepedirectory.com style: a flat `{ "image": "..." }` object
struct CounterpartyAssetManifest: Decodable {

    /// Top-level image URL string, when present
    let image: String?

    /// Array of typed image entries (e.g. icon/standard variants), when present
    let images: [ManifestImage]?

    struct ManifestImage: Decodable {
        let type: String?
        let data: String?
    }

    /// Resolve the best available image URL string from whichever schema this manifest used.
    /// Prefers the top-level `image` field, then a "standard" typed entry, then the first entry with data.
    var resolvedImageURLString: String? {
        if let image, !image.isEmpty {
            return image
        }

        guard let images else { return nil }

        if let standard = images.first(where: { $0.type == "standard" })?.data {
            return standard
        }

        return images.first(where: { $0.data != nil })?.data
    }
}
