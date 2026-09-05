//
//  HTMLMetadataParser.swift
//  StampFolio
//
//  Extracts document title from HTML stamp content
//

import Foundation

/// Pulls a document title from HTML stamp content (`<title>`, then Open Graph / meta title).
enum HTMLMetadataParser {

    static func title(from html: String) -> String? {
        if let value = firstCapture(in: html, pattern: "<title[^>]*>([\\s\\S]*?)</title>"),
           let title = cleaned(value) {
            return title
        }

        if let value = metaContent(in: html, attribute: "property", name: "og:title") {
            return cleaned(value)
        }

        if let value = metaContent(in: html, attribute: "name", name: "title") {
            return cleaned(value)
        }

        return nil
    }

    private static func metaContent(in html: String, attribute: String, name: String) -> String? {
        let quotedName = NSRegularExpression.escapedPattern(for: name)
        let attr = NSRegularExpression.escapedPattern(for: attribute)
        let patterns = [
            "<meta[^>]*\(attr)\\s*=\\s*[\"']\(quotedName)[\"'][^>]*content\\s*=\\s*[\"']([^\"']+)[\"']",
            "<meta[^>]*content\\s*=\\s*[\"']([^\"']+)[\"'][^>]*\(attr)\\s*=\\s*[\"']\(quotedName)[\"']"
        ]
        for pattern in patterns {
            if let value = firstCapture(in: html, pattern: pattern) {
                return value
            }
        }
        return nil
    }

    private static func firstCapture(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[capture])
    }

    private static func cleaned(_ raw: String) -> String? {
        var text = unescapeHTMLEntities(raw)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func unescapeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&amp;", "&")
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        return result
    }
}
