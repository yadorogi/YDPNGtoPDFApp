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
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 20) {
            Text(statusMessage)
                .multilineTextAlignment(.center)
                .padding()

            if isProcessing {
                ProgressView()
            }

            Button("フォルダを選んでPDFを作成") {
                selectFolderAndConvert()
            }
            .disabled(isProcessing)
            .padding()
        }
        .frame(width: 400, height: 200)
    }

    func selectFolderAndConvert() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "フォルダを選択"

        guard openPanel.runModal() == .OK, let folderURL = openPanel.url else { return }

        let outputPDFName = folderURL.lastPathComponent + ".pdf"
        let outputURL = folderURL.appendingPathComponent(outputPDFName)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            let alert = NSAlert()
            alert.messageText = "\(outputPDFName) は既に存在します"
            alert.informativeText = "上書きしてもよろしいですか?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "上書き")
            alert.addButton(withTitle: "キャンセル")
            guard alert.runModal() == .alertFirstButtonReturn else {
                statusMessage = "キャンセルしました"
                return
            }
        }

        isProcessing = true
        statusMessage = "変換中..."

        Task.detached(priority: .userInitiated) {
            let result = Self.convertPNGsToPDF(folderURL: folderURL, outputURL: outputURL)
            await MainActor.run {
                isProcessing = false
                statusMessage = result
            }
        }
    }

    static func naturalSorted(_ urls: [URL]) -> [URL] {
        urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func convertPNGsToPDF(folderURL: URL, outputURL: URL) -> String {
        let fileManager = FileManager.default
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentTypeKey])
        } catch {
            return "エラー: \(error.localizedDescription)"
        }

        let pngFiles = naturalSorted(contents.filter { url in
            if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
               let type = values.contentType {
                return type == .png
            }
            return false
        })

        guard !pngFiles.isEmpty else {
            return "PNGファイルが見つかりません"
        }

        let pdfDocument = PDFDocument()
        var failedFileNames: [String] = []

        for url in pngFiles {
            if let image = NSImage(contentsOf: url), let page = PDFPage(image: image) {
                pdfDocument.insert(page, at: pdfDocument.pageCount)
            } else {
                failedFileNames.append(url.lastPathComponent)
            }
        }

        guard pdfDocument.pageCount > 0 else {
            return "PDFに変換できる画像がありませんでした"
        }

        guard pdfDocument.write(to: outputURL) else {
            return "PDFの作成に失敗しました"
        }

        var message = "PDFを作成しました: \(outputURL.lastPathComponent)(\(pdfDocument.pageCount)ページ)"
        if !failedFileNames.isEmpty {
            message += "\n読み込めなかったファイル: \(failedFileNames.joined(separator: ", "))"
        }
        return message
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}