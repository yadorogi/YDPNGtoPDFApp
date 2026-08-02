//
//  YDPNGtoPDFAppTests.swift
//  YDPNGtoPDFAppTests
//
//  Created by Kawakami on 2025/06/17.
//

import Testing
import AppKit
import PDFKit
@testable import YDPNGtoPDFApp

struct YDPNGtoPDFAppTests {

    @Test func naturalSortOrdersNumericFilenamesCorrectly() async throws {
        let urls = ["page10.png", "page2.png", "page1.png", "page20.png"]
            .map { URL(fileURLWithPath: "/tmp/\($0)") }

        let sorted = ContentView.naturalSorted(urls).map(\.lastPathComponent)

        #expect(sorted == ["page1.png", "page2.png", "page10.png", "page20.png"])
    }

    @Test func convertPNGsToPDFReturnsMessageWhenFolderHasNoPNGs() async throws {
        let folderURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let outputURL = folderURL.appendingPathComponent("output.pdf")
        let result = ContentView.convertPNGsToPDF(folderURL: folderURL, outputURL: outputURL)

        #expect(result == "PNGファイルが見つかりません")
    }

    @Test func convertPNGsToPDFCombinesImagesInNaturalOrder() async throws {
        let folderURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: folderURL) }

        for name in ["img2.png", "img10.png", "img1.png"] {
            try writeSolidColorPNG(to: folderURL.appendingPathComponent(name))
        }

        let outputURL = folderURL.appendingPathComponent("output.pdf")
        let result = ContentView.convertPNGsToPDF(folderURL: folderURL, outputURL: outputURL)

        #expect(result.contains("3ページ"))
        let pdfDocument = try #require(PDFDocument(url: outputURL))
        #expect(pdfDocument.pageCount == 3)
    }

    @Test func convertPNGsToPDFReportsFilesThatFailToDecode() async throws {
        let folderURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: folderURL) }

        try writeSolidColorPNG(to: folderURL.appendingPathComponent("good.png"))
        try Data().write(to: folderURL.appendingPathComponent("broken.png"))

        let outputURL = folderURL.appendingPathComponent("output.pdf")
        let result = ContentView.convertPNGsToPDF(folderURL: folderURL, outputURL: outputURL)

        #expect(result.contains("1ページ"))
        #expect(result.contains("broken.png"))
        let pdfDocument = try #require(PDFDocument(url: outputURL))
        #expect(pdfDocument.pageCount == 1)
    }
}

private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeSolidColorPNG(to url: URL) throws {
    let image = NSImage(size: NSSize(width: 4, height: 4))
    image.lockFocus()
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: 4, height: 4).fill()
    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try pngData.write(to: url)
}
