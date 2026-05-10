//
//  AnalyzeImageTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 01.03.26.
//

import Foundation

/// A context-sensitive tool that lets the main model ask a vision or text model targeted questions
/// about images attached to the current conversation. Q&A results are persisted in the
/// attachment index so they are injected into future turns without re-calling the model.
struct AnalyzeImageTool: ChatTool {
    let conversationID: UUID

    static let defaultModel = "mistral-medium-latest"

    /// Models that support vision (image content will be included in the request).
    static let visionModels: Set<String> = [
        "mistral-medium-3.5",
        "mistral-large-latest",
        "mistral-medium-latest",
        "mistral-small-latest"
    ]

    var name: String { "analyze_image" }
    var displayName: String { "Analyze Image" }
    var description: String { "Analyze an image using a Mistral or Pixtral model" }
    var icon: String { "photo.badge.magnifyingglass" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "analyze_image",
                "description": """
                Analyze an image attached to the current conversation by sending it to a Mistral AI model.
                Only call this for images listed in the current message's attachments section.
                Use the exact filename shown (e.g. "abc123.jpg").

                Model selection guide:
                - mistral-medium-3.5: Best results. Significantly more expensive — use when accuracy matters most (detailed analysis, reading text in images, complex scenes).
                - mistral-large-latest: Strong general-purpose model. Use for deep reasoning about an image.
                - mistral-medium-latest (DEFAULT): Balanced choice. Use for straightforward image questions.
                - mistral-small-latest: Fastest and cheapest. Use for very simple visual questions.

                Default to mistral-medium-latest if you are unsure. Step up to mistral-medium-3.5 when the question demands the highest accuracy.

                To get started, ask the model to describe the image.
                Prefer targeted, specific questions rather than generic "describe this image" prompts for follow-up calls.
                Your questions and responses are visible to the user and cached for future turns.
                If a question has already been answered (visible in context above), do not ask it again.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "filename": [
                            "type": "string",
                            "description": "The exact filename of the image to analyze (e.g. 'abc123.jpg')"
                        ],
                        "question": [
                            "type": "string",
                            "description": "A specific question to ask about the image"
                        ],
                        "model": [
                            "type": "string",
                            "description": "The model to use. Defaults to mistral-medium-latest if omitted. Mistral Medium 3.5 is significantly more expensive than the other models but provides the best results. Pixtral models are now deprecated.",
                            "enum": [
                                "mistral-medium-3.5",
                                "mistral-large-latest",
                                "mistral-medium-latest",
                                "mistral-small-latest"
                            ]
                        ]
                    ],
                    "required": ["filename", "question"]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        arguments["question"] as? String ?? "Analyzing image…"
    }

    func execute(arguments: [String: Any]) async throws -> String {
        guard let filename = arguments["filename"] as? String,
              let question = arguments["question"] as? String else {
            throw NSError(domain: "AnalyzeImageTool", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing required arguments: filename and question"
            ])
        }

        let model = arguments["model"] as? String ?? Self.defaultModel
        let isVisionModel = Self.visionModels.contains(model)

        let apiKey = await MainActor.run { KeychainHelper.shared.mistralAPIKey }

        let answer: String
        if isVisionModel {
            guard let imageData = AttachmentManager.loadImage(filename: filename, for: conversationID) else {
                return "Error: Could not load image '\(filename)'. Make sure to use the exact filename from the attachments section."
            }

            let ext = (filename as NSString).pathExtension.lowercased()
            let mimeType: String
            switch ext {
            case "jpg", "jpeg": mimeType = "image/jpeg"
            case "png":         mimeType = "image/png"
            case "gif":         mimeType = "image/gif"
            case "webp":        mimeType = "image/webp"
            default:            mimeType = "image/jpeg"
            }

            let dataURL = "data:\(mimeType);base64,\(imageData.base64EncodedString())"
            answer = try await callModel(apiKey: apiKey, model: model, question: question, imageDataURL: dataURL)
        } else {
            answer = try await callModel(apiKey: apiKey, model: model, question: question, imageDataURL: nil)
        }

        // Persist the Q&A so future turns see it without re-calling the model
        let imageUUID = (filename as NSString).deletingPathExtension
        AttachmentManager.addQA(imageUUID: imageUUID, question: question, answer: answer, for: conversationID)

        return answer
    }

    private func callModel(apiKey: String, model: String, question: String, imageDataURL: String?) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let content: Any
        if let dataURL = imageDataURL {
            content = [
                ["type": "image_url", "image_url": ["url": dataURL]],
                ["type": "text", "text": question]
            ]
        } else {
            content = question
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": content]],
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let responseContent = message["content"] as? String else {
            throw NSError(domain: "AnalyzeImageTool", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unexpected response from \(model)"
            ])
        }

        let generationModelMark = "Generated by \(model)"
        return "\(responseContent)\n\n*\(generationModelMark)*"
    }
}
