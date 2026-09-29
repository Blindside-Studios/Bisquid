//
//  QuickLookHelper.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.03.26.
//

import SwiftUI

extension View {
    /// Opens Quick Look on tap. On iOS the preview zooms out of this view and can be swiped
    /// or pinched back into it — without a source view, iOS 27 offers no dismiss gesture at all.
    func quickLookOnTap(url: @escaping () -> URL) -> some View {
        modifier(QuickLookOnTap(url: url))
    }
}

#if os(iOS)
import UIKit
import QuickLook

enum QuickLookHelper {
    /// Opens the system Quick Look viewer for a file URL — the same full-screen
    /// viewer used by Files app, with share sheet, markup, etc.
    /// `sourceView` is what the preview zooms out of and back into when dismissed.
    static func open(url: URL, from sourceView: UIView? = nil) {
        let controller = QLPreviewController()
        let dataSource = QLDataSource(url: url, sourceView: sourceView)
        controller.dataSource = dataSource
        controller.delegate = dataSource
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
        open(url: tempURL(for: data, fileExtension: fileExtension))
    }

    private class QLDataSource: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let url: URL
        weak var sourceView: UIView?
        init(url: URL, sourceView: UIView?) {
            self.url = url
            self.sourceView = sourceView
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }

        func previewController(_ controller: QLPreviewController, transitionViewFor item: QLPreviewItem) -> UIView? {
            // Gone if the thumbnail scrolled out of a lazy stack meanwhile; QL falls back to a plain fade
            sourceView?.window != nil ? sourceView : nil
        }
    }
}

private struct QuickLookOnTap: ViewModifier {
    let url: () -> URL
    @State private var anchor = QuickLookAnchor.Box()

    func body(content: Content) -> some View {
        content
            .background(QuickLookAnchor(box: anchor))
            .onTapGesture {
                QuickLookHelper.open(url: url(), from: anchor.view)
            }
    }
}

/// An invisible UIView sitting exactly behind the SwiftUI content, so Quick Look has a real
/// view (and frame) to zoom from. SwiftUI views have no UIView of their own to hand over.
private struct QuickLookAnchor: UIViewRepresentable {
    final class Box {
        weak var view: UIView?
    }

    let box: Box

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        box.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        box.view = uiView
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
        open(url: tempURL(for: data, fileExtension: fileExtension))
    }
}

private struct QuickLookOnTap: ViewModifier {
    let url: () -> URL

    func body(content: Content) -> some View {
        content.onTapGesture { QuickLookHelper.open(url: url()) }
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

extension QuickLookHelper {
    /// Writes data to a temp file Quick Look can open. Overwritten on each call; not cleaned up automatically.
    static func tempURL(for data: Data, fileExtension: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relista_preview")
            .appendingPathExtension(fileExtension)
        try? data.write(to: url)
        return url
    }
}
