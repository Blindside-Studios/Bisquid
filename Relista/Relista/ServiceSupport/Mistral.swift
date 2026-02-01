//
//  Mistral.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import Foundation
import SwiftUI

enum StreamChunk {
    case content(String)
    case annotations([MessageAnnotation])
}

struct Mistral {
    let apiKey: String

    var url: URL {
        URL(string: "https://api.mistral.ai/v1/chat/completions")!
    }

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func generateChatName(messages: [Message]) async throws -> String {
        var request = makeRequest()

        let systemMessage = [
            "role": "user",
            "content": """
            Create a short title (3 words, max 4 words) describing the topic of the FIRST user message and the FIRST assistant reply.
            Output the title as plain text only - no quotes, no punctuation marks around it.
            Same language as the user.

            Incorrect: "Recipe Ideas"
            Correct: Recipe Ideas
            """
        ]

        let apiMessages = messages.filter{$0.role == .assistant || $0.role == .user}.map {
            ["role": $0.role.toAPIString(), "content": $0.text]
        } + [systemMessage]

        let body: [String: Any] = [
            "model": "ministral-3b-latest",
            "messages": apiMessages,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let choices = json["choices"] as! [[String: Any]]
        let messageObj = choices[0]["message"] as! [String: Any]
        return messageObj["content"] as! String
    }
    
    func generateGreetingBanner(agent: UUID?) async throws -> String {
        var request = makeRequest()
        let defaultInstructions = await MainActor.run { SyncedSettings.shared.defaultInstructions }
        let userName = await MainActor.run { SyncedSettings.shared.userName }
                
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' HH:mm"
        var timeString = formatter.string(from: Date.now)
        if Int.random(in: 1...2) != 1 { timeString = "unspecified" }
        
        let instructions = agent == nil ? defaultInstructions : agent
            .flatMap { AgentManager.getAgent(fromUUID: $0)?.systemPrompt } ?? ""
        
        let systemMessage = [
            "role": "user",
            "content": """
            You will write a short greeting (keep it brief, up to 3 to 8 words) to be displayed in the UI of a chat application as a banner above the text input box.
            This greeting will not be part of the conversation later-on, it is just meant to invite the user to type something.
            Further below, you will find the system prompt for your current persona that the user has specified.
            Stylistically, you will adopt said persona and make sure its personality shines through clearly while focusing on what makes sense as a greeting.
            Disregard formatting requests as well as those for stage directions.
            Keep the greeting engaging, slightly endearing and interesting without overdoing it.
            
            Here are the criteria your greetings must follow with positive and negative examples:
            If the user-specified instructions request the use of another language, use that language. For example, if instructed to speak German:
            Good response: Hey, wie läuft's?
            Bad response: Hey, what's up?
            
            If the system adds helpful parameters, do not go for generic greetings. For example, if the time is stated to be 22:30:
            Good response: Still working, night owl?
            Bad response: Good evening
            
            Do not wrap your answer in quotation marks:
            Good response: I got you!
            Bas response: "I got you!"
            
            Do not end your sentence with periods. Exclamation and question marks are allowed:
            Good response: Happy to see you
            Bad response: Happy to see you.
            
            CRITICAL: Do NOT markdown format responses or use stage directions:
            Good response: What's up now?
            Bad response: *smirks* What's up now?
            
            Here is helpful data to allow you to make your answers more personalized (if a field is blank, do not mention it).
            You may not use the name consistently as it would be creepy, only use it rarely and if you feel it adds to the greeting you wrote.
            Use the time OCCASIONALLY to customize your greeting to fit a late evening vibe or even comment on the current date, wishing to use Merry Christmas etc.
            User-specified name: \(userName)
            Current date and time: \(timeString)
            
            If the user-specified instructions are blank, you should fall back to general-purpose, friendly greetings, still with personality.
            Below is your persona's system prompt as given by the user.
            -- PERSONA SYSTEM PROMPT --
            \(instructions)
            -- END OF PERSONA SYSTEM PROMPT --
            
            KEEP IN MIND THAT YOUR RESPONSES MUST NOT BE LONGER THAN 8 WORDS AND YOU MUST DISREGARD INSTRUCTIONS FROM THE USER ABOUT MESSAGE LENGTH, STAGE DIRECTIONS OR MARKDOWN!!!
            I REPEAT: NO STAGE DIRECTIONS, NO FORMATTING, NO LINE BREAKS OR NEWLINES, NO QUOTATION MARKS, NO ASTERISKS!!!
            YOUR ENTIRE RESPONSE SHOULD BE THE GREETING FOR THE UI AND NOTHING ELSE!!!
            """
        ]

        let apiMessages = [systemMessage]

        let body: [String: Any] = [
            "model": "ministral-8b-latest",
            "messages": apiMessages,
            "stream": false,
            "temperature": 1.0
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let choices = json["choices"] as! [[String: Any]]
        let messageObj = choices[0]["message"] as! [String: Any]
        let greeting = messageObj["content"] as! String
        
        // we will be sanitizing this content because depending on the user's instructions, the model may still try to markdown.
        var cleaned = greeting
                // remove everything inside and including asterisks (role play stage directions)
                .replacingOccurrences(of: #"\*[^*]*\*"#, with: "", options: .regularExpression)
                // remove remaining standalone asterisks
                .replacingOccurrences(of: "*", with: "")
                // remove all line breaks
                .replacingOccurrences(of: "\n", with: " ")
                // replace em dashes with spaced hyphens
                .replacingOccurrences(of: "—", with: " - ")
                // trim whitespace
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // remove leading/trailing quotes
            if cleaned.hasPrefix("\"") { cleaned.removeFirst() }
            if cleaned.hasSuffix("\"") { cleaned.removeLast() }
            
            // clean up multiple spaces
            cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            
            let finalGreeting = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
            return finalGreeting
    }

    func streamMessage(messages: [Message], modelName: String, agent: UUID?, useSearch: Bool = false) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        var request = makeRequest()
        let defaultInstructions = await MainActor.run { SyncedSettings.shared.defaultInstructions }

        let systemMessage = [
            "role": "system",
            "content": agent == nil ? defaultInstructions : agent
                .flatMap { AgentManager.getAgent(fromUUID: $0)?.systemPrompt } ?? ""
        ]

        let apiMessages = [systemMessage] + messages.map { message in
            var content = message.text
            // replace blank messages with placeholder (Mistral requires non-empty content)
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = "[No message content]"
            }
            return ["role": message.role.toAPIString(), "content": content]
        }

        // Note: Mistral API supports web searches but it's not yet implemented, like reasoning
        // The useSearch parameter is kept for API compatibility but ignored
        if useSearch {
            print("⚠️ Web search requested not yet implemented for Mistral")
        }

        print("🔍 Model being used: \(modelName)")
        print("📨 Request URL: \(request.url?.absoluteString ?? "nil")")
        print("📨 Request headers: \(request.allHTTPHeaderFields ?? [:])")

        let body: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, _) = try await URLSession.shared.bytes(for: request)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        // Log every line received for debugging
                        if !line.isEmpty {
                            print("📥 Received line: \(line)")
                        }

                        // check for error responses (they don't have "data: " prefix)
                        if line.hasPrefix("{") && line.contains("\"error\"") {
                            print("❌ ERROR RESPONSE DETECTED")
                            print("❌ Full error line: \(line)")

                            if let jsonData = line.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                print("❌ Parsed error JSON: \(json)")

                                if let errorDict = json["error"] as? [String: Any] {
                                    print("❌ Error dict: \(errorDict)")
                                    let errorMessage = errorDict["message"] as? String ?? "Unknown error"
                                    let errorType = errorDict["type"] as? String ?? "unknown"
                                    let errorCode = errorDict["code"] as? String ?? "unknown"

                                    print("❌ Error message: \(errorMessage)")
                                    print("❌ Error type: \(errorType)")
                                    print("❌ Error code: \(errorCode)")

                                    let error = NSError(domain: "Mistral", code: 1, userInfo: [
                                        NSLocalizedDescriptionKey: errorMessage,
                                        "type": errorType,
                                        "code": errorCode
                                    ])
                                    continuation.finish(throwing: error)
                                    return
                                }
                            }
                        }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = line.dropFirst(6)
                        if data == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        if let jsonData = data.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any] {

                            // yield content if present
                            if let content = delta["content"] as? String {
                                continuation.yield(.content(content))
                            }

                            // yield annotations if present (though Mistral may not support this)
                            if let annotationsData = delta["annotations"] as? [[String: Any]] {
                                let annotations = try? self.parseAnnotations(annotationsData)
                                if let annotations = annotations {
                                    continuation.yield(.annotations(annotations))
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func parseAnnotations(_ annotationsData: [[String: Any]]) throws -> [MessageAnnotation] {
        let jsonData = try JSONSerialization.data(withJSONObject: annotationsData)
        let decoder = JSONDecoder()
        return try decoder.decode([MessageAnnotation].self, from: jsonData)
    }
}
