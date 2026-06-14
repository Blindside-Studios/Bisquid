//
//  CanvasOCR.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 14.06.26.
//


import Foundation
import PencilKit
import UIKit

enum CanvasOCR {
    /// Renders a `PKDrawing` to PNG data suitable for OCR.
    ///
    /// PNG (not JPEG) because handwriting is sharp dark strokes on a light ground:
    /// JPEG smears those edges with ringing artifacts, while PNG stays lossless *and*
    /// compresses this kind of content very tightly. The strokes are composited onto
    /// opaque white because PencilKit draws on transparency and OCR wants ink-on-paper.
    ///
    /// - Parameters:
    ///   - drawing: The canvas content, e.g. `canvasView.drawing`.
    ///   - scale: Render scale. 2.0 is a good default for handwriting; bump to 3.0 for
    ///            very small or dense script, lower it to trim payload size.
    ///   - padding: Margin (in points) added around the tight stroke bounds so glyphs
    ///              at the edge aren't clipped.
    /// - Returns: PNG bytes, or `nil` if the drawing is empty.
    static func pngData(from drawing: PKDrawing,
                        scale: CGFloat = 2.0,
                        padding: CGFloat = 16) -> Data? {
        let bounds = drawing.bounds
        guard bounds.width > 0, bounds.height > 0,
              bounds.width.isFinite, bounds.height.isFinite else {
            return nil
        }

        let rect = bounds.insetBy(dx: -padding, dy: -padding)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: rect.size))
            drawing.image(from: rect, scale: scale)
                   .draw(in: CGRect(origin: .zero, size: rect.size))
        }

        return image.pngData()
    }

    /// Sends image data to Mistral's `/v1/ocr` endpoint and returns the extracted text.
    ///
    /// - Parameters:
    ///   - imageData: PNG (or JPEG) bytes
    ///   - apiKey: the Mistral API key
    ///   - mimeType: Defaults to `image/png`; pass `image/jpeg` if encoded JPEG
    /// - Returns: The recognised text, with one blank line between pages
    static func extractText(from imageData: Data,
                            apiKey: String,
                            mimeType: String = "image/png") async throws -> String {
        let dataURI = "data:\(mimeType);base64,\(imageData.base64EncodedString())"

        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/ocr")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "mistral-ocr-latest",
            "document": [
                "type": "image_url",
                "image_url": dataURI
            ],
            // currently we only take the text back, no images
            "include_image_base64": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OCRError.transport
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "<no body>"
            throw OCRError.server(status: http.statusCode, body: detail)
        }

        let decoded = try JSONDecoder().decode(OCRResponse.self, from: data)
        return decoded.pages
            .map(\.markdown)
            .joined(separator: "\n\n")
    }

    // We only decode the fields we need; Mistral returns more (images, bboxes, usage).
    private struct OCRResponse: Decodable {
        struct Page: Decodable { let markdown: String }
        let pages: [Page]
    }

    enum OCRError: LocalizedError {
        case transport
        case server(status: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .transport:
                return "No valid HTTP response from the OCR service."
            case let .server(status, body):
                return "OCR request failed (\(status)): \(body)"
            }
        }
    }
}

extension CanvasOCR {
    static func recognize(_ drawing: PKDrawing,
                          apiKey: String,
                          scale: CGFloat = 2.0) async throws -> String {
        guard let data = pngData(from: drawing, scale: scale) else { return "" }
        return try await extractText(from: data, apiKey: apiKey)
    }
}
