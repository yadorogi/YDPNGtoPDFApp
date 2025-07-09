//
//  ContentView.swift
//  YDPNGtoPDFApp (macOS 12+)
//
//  Created by Kawakami on 2025/06/17.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var statusMessage = "フォルダを選択してPNG→PDF変換"

    var body: some View {
        VStack(spacing: 20) {
            Text(statusMessage)
                .padding()

            Button("フォルダを選んでPDFを作成") {
                convertFolderPNGsToPDF()
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }

    func convertFolderPNGsToPDF() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "フォルダを選択"

        if openPanel.runModal() == .OK, let folderURL = openPanel.url {
            do {
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)

                let pngFiles = contents.filter {
                    guard let type = try? $0.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                        return false
                    }
                    return type == .png
                }.sorted { a, b in
                    a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
                }.sorted { a, b in
                    a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
                } // ファイル名順にソート

                guard !pngFiles.isEmpty else {
                    statusMessage = "PNGファイルが見つかりません"
                    return
                }

                let pdfDocument = PDFDocument()
                for (index, url) in pngFiles.enumerated() {
                    if let image = NSImage(contentsOf: url),
                       let page = PDFPage(image: image) {
                        pdfDocument.insert(page, at: index)
                    }
                }

                let outputPDFName = folderURL.lastPathComponent + ".pdf"
                let outputURL = folderURL.appendingPathComponent(outputPDFName)

                if pdfDocument.write(to: outputURL) {
                    statusMessage = "PDFを作成しました: \(outputPDFName)"
                } else {
                    statusMessage = "PDFの作成に失敗しました"
                }

            } catch {
                statusMessage = "エラー: \(error.localizedDescription)"
            }
        }
    }
}
