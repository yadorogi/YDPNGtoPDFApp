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
    @State private var statusMessage = ContentView.localized("status.initial", "フォルダを選択して画像をPDFに変換")
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
        openPanel.prompt = Self.localized("picker.selectFolderPrompt", "フォルダを選択")

        guard openPanel.runModal() == .OK, let folderURL = openPanel.url else { return }

        let outputPDFName = folderURL.lastPathComponent + ".pdf"
        let outputURL = folderURL.appendingPathComponent(outputPDFName)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            let alert = NSAlert()
            alert.messageText = String(format: Self.localized("alert.overwriteTitle", "%@ は既に存在します"), outputPDFName)
            alert.informativeText = Self.localized("alert.overwriteMessage", "上書きしてもよろしいですか?")
            alert.alertStyle = .warning
            alert.addButton(withTitle: Self.localized("alert.overwriteConfirm", "上書き"))
            alert.addButton(withTitle: Self.localized("alert.cancel", "キャンセル"))
            guard alert.runModal() == .alertFirstButtonReturn else {
                statusMessage = Self.localized("status.cancelled", "キャンセルしました")
                return
            }
        }

        isProcessing = true
        statusMessage = Self.localized("status.converting", "変換中...")

        Task.detached(priority: .userInitiated) {
            let result = Self.convertImagesToPDF(folderURL: folderURL, outputURL: outputURL)
            await MainActor.run {
                isProcessing = false
                statusMessage = result
            }
        }
    }

    static func naturalSorted(_ urls: [URL]) -> [URL] {
        urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// フォルダ内から変換対象として拾い上げる画像フォーマット。今後の拡充はここに追加する。
    static let supportedImageTypes: Set<UTType> = [.png, .jpeg]

    static func convertImagesToPDF(folderURL: URL, outputURL: URL) -> String {
        let fileManager = FileManager.default
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentTypeKey])
        } catch {
            return String(format: localized("status.error", "エラー: %@"), error.localizedDescription)
        }

        let imageFiles = naturalSorted(contents.filter { url in
            if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
               let type = values.contentType {
                return supportedImageTypes.contains(type)
            }
            return false
        })

        guard !imageFiles.isEmpty else {
            return localized("status.noImagesFound", "画像ファイルが見つかりません")
        }

        let pdfDocument = PDFDocument()
        var failedFileNames: [String] = []

        for url in imageFiles {
            if let image = NSImage(contentsOf: url), let page = PDFPage(image: image) {
                pdfDocument.insert(page, at: pdfDocument.pageCount)
            } else {
                failedFileNames.append(url.lastPathComponent)
            }
        }

        guard pdfDocument.pageCount > 0 else {
            return localized("status.noConvertibleImages", "PDFに変換できる画像がありませんでした")
        }

        guard pdfDocument.write(to: outputURL) else {
            return localized("status.writeFailed", "PDFの作成に失敗しました")
        }

        var message = String(
            format: localized("status.pdfCreated", "PDFを作成しました: %@(%@ページ)"),
            outputURL.lastPathComponent,
            "\(pdfDocument.pageCount)"
        )
        if !failedFileNames.isEmpty {
            message += String(
                format: localized("status.failedFiles", "\n読み込めなかったファイル: %@"),
                failedFileNames.joined(separator: ", ")
            )
        }
        return message
    }

    /// String Catalog(Localizable.xcstrings)からキーを引く。未登録キーの場合はdefaultValueをそのまま表示する。
    static func localized(_ key: String, _ defaultValue: String) -> String {
        NSLocalizedString(key, bundle: .main, value: defaultValue, comment: "")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
