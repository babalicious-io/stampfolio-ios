//
//  MarkdownDocumentView.swift
//  StampFolio
//
//  Renders bundled Markdown documents as formatted readable text.
//

import SwiftUI

/// Displays a bundled `.md` file as formatted text (headings, lists, tables, code, links).
struct MarkdownDocumentView: View {
    
    let resourceName: String
    let title: String
    
    @State private var attributedContent: AttributedString?
    @State private var loadError: String?
    @Environment(\.appColorScheme) private var appColorScheme
    
    var body: some View {
        Group {
            if let attributedContent {
                ScrollView {
                    Text(attributedContent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .textSelection(.enabled)
                }
            } else if let loadError {
                ContentUnavailableView {
                    Label("Could Not Load Document", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text(loadError)
                }
            } else {
                ProgressView()
                    .tint(appColorScheme.primary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDocument()
        }
    }
    
    @MainActor
    private func loadDocument() async {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "md") else {
            loadError = "Document “\(resourceName).md” was not found in the app bundle."
            return
        }
        
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .full
            options.allowsExtendedAttributes = true
            
            attributedContent = try AttributedString(markdown: markdown, options: options)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        MarkdownDocumentView(
            resourceName: "MICROPYTHON-PRESTO-PORT",
            title: "Presto Port Research"
        )
    }
}
