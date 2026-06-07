//
//  QuickLookHelper.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.03.26.
//

import Foundation

#if os(iOS)
import UIKit
import QuickLook

enum QuickLookHelper {
    /// Opens the system Quick Look viewer for a file URL — the same full-screen
    /// viewer used by Files app, with share sheet, markup, etc.
    static func open(url: URL) {
        let controller = QLPreviewController()
        let dataSource = QLDataSource(url: url)
        controller.dataSource = dataSource
        // Keep the data source alive for the controller's lifetime
        objc_setAssociatedObject(controller, "qlDataSource", dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        // Walk up to the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(controller, animated: true)
    }

    /// Writes image data to a temp file and opens Quick Look on it.
    /// The temp file is overwritten on each call; it is not cleaned up automatically.
    static func open(data: Data, fileExtension: String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relista_preview")
            .appendingPathExtension(fileExtension)
        try? data.write(to: url)
        open(url: url)
    }

    private class QLDataSource: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

#elseif os(macOS)
import AppKit
import QuickLookUI

enum QuickLookHelper {
    /// Opens the system Quick Look panel (the same floating panel as spacebar in Finder).
    static func open(url: URL) {
        QLPanelManager.shared.open(url: url)
    }

    /// Writes image data to a temp file and opens Quick Look on it.
    static func open(data: Data, fileExtension: String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relista_preview")
            .appendingPathExtension(fileExtension)
        try? data.write(to: url)
        open(url: url)
    }
}

/// Singleton that owns the QL panel data source on macOS.
/// Setting the panel's data source directly works without needing the responder chain.
final class QLPanelManager: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QLPanelManager()
    private var currentURL: URL?

    func open(url: URL) {
        currentURL = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { 1 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        currentURL as (any QLPreviewItem)?
    }
}

#endif
