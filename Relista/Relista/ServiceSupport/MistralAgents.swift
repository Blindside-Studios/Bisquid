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

    var chatCompletionsUrl: URL {
        URL(string: "https://api.mistral.ai/v1/chat/completions")!
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

    // MARK: - Smart Grounding

    /// Runs the smart grounding agent to generate a context injection for the main model.
    /// Returns a trimmed injection string. An empty string means "no injection needed".
    /// Any thrown error should be treated by the caller as "no injection needed".
    ///
    /// Implementation note: the spec calls for an /v1/agents + /v1/conversations agent
    /// with Mistral's native web_search tool. We use /v1/chat/completions with function
    /// tools instead — the web_search function tool wraps `executeSearch`, which itself
    /// uses the search agent defined above, so the result is still Mistral's native web
    /// search. This path reuses our proven tool infrastructure and avoids the function
    /// call loop over the conversations API.
    func executeSmartGrounding(
        systemPromptExcerpt: String,
        currentUserMessage: String,
        previousUserMessage: String?,
        previousAssistantMessage: String?,
        previousInjections: [String],
        useWebSearch: Bool
    ) async throws -> String {
        // Snapshot the wiki entries from the main thread so WikisTool can operate off-thread.
        let wikiSnapshot = await MainActor.run { SyncedSettings.shared.wikiEntries }
        let wikisTool = WikisTool(entrySnapshot: wikiSnapshot)

        var tools: [any ChatTool] = [
            CurrentTimeTool(),
            KnowledgeRefresherTool(),
            wikisTool
        ]
        if useWebSearch {
            tools.append(WebSearchTool())
        }

        let instructions = """
        You are Smart Grounding, a background assistant for the Bisquid chat app.
        Your job: inspect the user's latest message and optionally return a short \
        knowledge injection that will be appended to that message inside \
        `<system_smart_grounding>...</system_smart_grounding>` tags for the main chat \
        model to read.

        When to provide an injection:
        - The question likely touches information past a 2024 training cutoff. Use the \
          `knowledge_refresher` tool, and/or `web_search` if available, then state the \
          relevant facts. If you cannot confirm recent facts, tell the main model to \
          acknowledge the gap or use the web search tool itself.
        - The main model is roleplaying a persona (inspect its system prompt excerpt). \
          Provide period- or context-appropriate factual grounding so the response stays \
          tonally and historically accurate.
        - Any other case where a small, focused fact dump would measurably improve the \
          main model's answer.

        When to RETURN AN EMPTY RESPONSE (no injection):
        - The user's question is answerable from standard pre-2024 general knowledge.
        - The user explicitly asks the main model to use a tool ("search the web", \
          "look it up", "what's the time", etc.) — the main model will handle it itself.
        - You have nothing useful to add.
        - The previous injections shown below already cover the relevant ground, and \
          the current user turn does not need new information.

        Using Wikis:
        - `wikis` read/add lets you consult and extend a persistent knowledge base.
        - When you learn something via web search that is likely to matter again in the \
          future (e.g., "iOS 26 released 2025", "current US president name"), add it to \
          an appropriate category. Do NOT add trivia (e.g., "top running speed of a \
          giraffe"). Always read the relevant category first before adding to avoid \
          duplicates.

        Output format:
        - Plain text, 1-3 short paragraphs, briefing-style. Do not address the user. \
          Do not introduce yourself. Do not wrap in tags — the wrapping tags are added \
          around your output automatically.
        - If no injection is needed, return a completely empty response.
        """

        let priorUserBlock = (previousUserMessage?.isEmpty == false) ? previousUserMessage! : "(none)"
        let priorAssistantBlock = (previousAssistantMessage?.isEmpty == false) ? previousAssistantMessage! : "(none)"
        let priorInjectionsBlock: String
        if previousInjections.isEmpty {
            priorInjectionsBlock = "(none)"
        } else {
            priorInjectionsBlock = previousInjections
                .enumerated()
                .map { "[\($0.offset + 1)] \($0.element)" }
                .joined(separator: "\n\n")
        }

        let userContent = """
        # Main model system prompt (first 800 characters)
        \(systemPromptExcerpt)

        # Previous user message
        \(priorUserBlock)

        # Previous assistant message
        \(priorAssistantBlock)

        # Prior smart grounding injections (do not repeat these)
        \(priorInjectionsBlock)

        # Current user message
        \(currentUserMessage)

        Provide the injection, or reply with an empty response if none is needed.
        """

        var messages: [[String: Any]] = [
            ["role": "system", "content": instructions],
            ["role": "user", "content": userContent]
        ]

        let maxIterations = 5
        for iteration in 0..<maxIterations {
            var request = makeRequest(url: chatCompletionsUrl)
            let body: [String: Any] = [
                "model": "ministral-14b-latest",
                "messages": messages,
                "tools": tools.map { $0.definition },
                "stream": false,
                "temperature": 0.2
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let choice = choices.first,
                  let message = choice["message"] as? [String: Any] else {
                return ""
            }

            if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
                var assistantMsg: [String: Any] = [
                    "role": "assistant",
                    "tool_calls": toolCalls
                ]
                if let content = message["content"] as? String, !content.isEmpty {
                    assistantMsg["content"] = content
                }
                messages.append(assistantMsg)

                for call in toolCalls {
                    guard let fn = call["function"] as? [String: Any],
                          let name = fn["name"] as? String,
                          let id = call["id"] as? String else { continue }
                    let argsStr = fn["arguments"] as? String ?? "{}"
                    let args = (try? JSONSerialization.jsonObject(
                        with: Data(argsStr.utf8)
                    ) as? [String: Any]) ?? [:]

                    let result: String
                    if let tool = tools.first(where: { $0.name == name }) {
                        do {
                            result = try await tool.execute(arguments: args)
                        } catch {
                            result = "Tool \(name) failed: \(error.localizedDescription)"
                        }
                    } else {
                        result = "Unknown tool: \(name)"
                    }

                    messages.append([
                        "role": "tool",
                        "tool_call_id": id,
                        "content": result
                    ])
                }

                print("🧭 Smart grounding iteration \(iteration + 1): executed \(toolCalls.count) tool call(s)")
                continue
            }

            let content = (message["content"] as? String) ?? ""
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        print("🧭 Smart grounding: hit max iterations without final text")
        return ""
    }
}
