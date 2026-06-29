//
//  PDFSupport.swift
//  PreferenceFlow
//

import SwiftUI
import PDFKit

/// Extracts plain text and basic metadata from a PDF on disk. `nonisolated` so it
/// can run off the main actor during import.
nonisolated enum PDFTextExtractor {
    struct Result {
        let text: String
        let pageCount: Int
    }

    /// Reads the PDF at `url` and returns its concatenated text plus page count.
    /// Returns empty text (not nil) when a PDF has no extractable text layer.
    static func extract(from url: URL) -> Result {
        guard let document = PDFDocument(url: url) else {
            return Result(text: "", pageCount: 0)
        }
        var pieces: [String] = []
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let text = page.string {
                pieces.append(text)
            }
        }
        return Result(text: pieces.joined(separator: "\n"), pageCount: document.pageCount)
    }
}

/// A SwiftUI wrapper around `PDFView` that displays a document and supports
/// programmatic in-document search highlighting.
struct PDFKitView: UIViewRepresentable {
    let url: URL
    /// Search term to highlight; pass an empty string to clear.
    var searchText: String = ""

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        if let document = PDFDocument(url: url) {
            view.document = document
        }
        context.coordinator.pdfView = view
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document == nil, let document = PDFDocument(url: url) {
            view.document = document
        }
        context.coordinator.highlight(searchText)
    }

    final class Coordinator {
        weak var pdfView: PDFView?
        private var lastSearch = ""

        func highlight(_ term: String) {
            guard term != lastSearch else { return }
            lastSearch = term
            guard let pdfView, let document = pdfView.document else { return }
            pdfView.highlightedSelections = nil
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let matches = document.findString(trimmed, withOptions: [.caseInsensitive, .diacriticInsensitive])
            guard !matches.isEmpty else { return }
            for match in matches { match.color = UIColor.systemYellow }
            pdfView.highlightedSelections = matches
            if let first = matches.first {
                pdfView.go(to: first)
                pdfView.setCurrentSelection(first, animate: true)
            }
        }
    }
}
