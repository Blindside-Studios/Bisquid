//
//  MistralAgents.swift
//  Relista
//
//  Created by Claude Code on 25.02.26.
//

import Foundation

struct MistralAgents {
    let apiKey: String

    var agentsUrl: URL {
        URL(string: "https://api.mistral.ai/v1/agents")!
    }

    var conversationsUrl: URL {
        URL(string: "https://api.mistral.ai/v1/conversations")!
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    // Create or reuse a web search agent
    func getOrCreateSearchAgent(searchType: String, isPremium: Bool = false) async throws -> String {
        // For now, we'll create a new agent each time
        // TODO: Cache the agent ID for reuse
        return try await createSearchAgent(searchType: searchType, isPremium: isPremium)
    }

    private func createSearchAgent(searchType: String, isPremium: Bool = false) async throws -> String {
        var request = makeRequest(url: agentsUrl)

        let body: [String: Any] = [
            "model": isPremium ? "mistral-medium-latest" : "mistral-small-latest",
            "name": "Web Search Agent",
            "description": "Agent for performing web searches",
            "instructions": "You are a web search assistant. Perform searches to answer user queries accurately.",
            "tools": [["type": searchType]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🤖 Creating web search agent...")
        let (data, response) = try await URLSession.shared.data(for: request)

        // Log the response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 Agent creation response status: \(httpResponse.statusCode)")
        }

        if let responseString = String(data: data, encoding: .utf8) {
            print("📡 Agent creation response: \(responseString)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        print("📡 Parsed JSON keys: \(json.keys)")

        guard let agentId = json["id"] as? String else {
            throw NSError(domain: "MistralAgents", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create agent: no ID returned. Response: \(json)"
            ])
        }

        print("✓ Created agent: \(agentId)")
        return agentId
    }

    // Execute a web search using the agent
    func executeSearch(query: String, searchType: String = "web_search") async throws -> String {
        let agentId = try await getOrCreateSearchAgent(searchType: searchType, isPremium: searchType == "web_search_premium")

        var request = makeRequest(url: conversationsUrl)

        let body: [String: Any] = [
            "agent_id": agentId,
            "inputs": query,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🔍 Executing search with \(searchType): \(query)")
        let (data, response) = try await URLSession.shared.data(for: request)

        // Log the response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 Conversation response status: \(httpResponse.statusCode)")
        }

        if let responseString = String(data: data, encoding: .utf8) {
            print("📡 Conversation response: \(responseString)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        print("📡 Parsed conversation JSON keys: \(json.keys)")

        // Extract the search results from the conversation response
        // The response structure includes outputs with message.output type
        guard let outputs = json["outputs"] as? [[String: Any]] else {
            throw NSError(domain: "MistralAgents", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to get conversation outputs. Response keys: \(json.keys)"
            ])
        }

        // Find the message output entry
        for output in outputs {
            guard let type = output["type"] as? String, type == "message.output" else { continue }

            // content can be either a plain String or an array of typed chunks
            if let plainText = output["content"] as? String, !plainText.isEmpty {
                print("✓ Search completed (plain string), got \(plainText.count) characters")
                return plainText
            }

            if let content = output["content"] as? [[String: Any]] {
                var resultText = ""
                var citations: [(title: String, url: String, date: String?)] = []

                for chunk in content {
                    if let chunkType = chunk["type"] as? String {
                        if chunkType == "text", let text = chunk["text"] as? String {
                            resultText += text
                        } else if chunkType == "tool_reference",
                                  let title = chunk["title"] as? String,
                                  let url = chunk["url"] as? String {
                            let date = chunk["date"] as? String
                            citations.append((title: title, url: url, date: date))
                        }
                    }
                }

                if !resultText.isEmpty {
                    print("✓ Search completed, got \(resultText.count) characters and \(citations.count) citations")

                    if !citations.isEmpty {
                        resultText += "\n\n**Sources**\n"
                        for citation in citations {
                            var line = "- [\(citation.title)](\(citation.url))"
                            if let date = citation.date, date.count >= 10 {
                                line += " · \(date.prefix(10))"
                            }
                            resultText += line + "\n"
                        }
                    }

                    return resultText
                }
            }
        }

        throw NSError(domain: "MistralAgents", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "No search results found in conversation"
        ])
    }
}
