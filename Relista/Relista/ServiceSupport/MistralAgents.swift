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

    // Delete a previously-created agent. Best-effort: errors are logged but not thrown,
    // since cleanup failure shouldn't surface to the user.
    private func deleteAgent(agentId: String) async {
        guard let url = URL(string: "https://api.mistral.ai/v1/agents/\(agentId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("🗑️ Agent \(agentId) deletion response status: \(httpResponse.statusCode)")
            }
        } catch {
            print("⚠️ Failed to delete agent \(agentId): \(error.localizedDescription)")
        }
    }

    // Execute a web search using the agent
    func executeSearch(query: String, searchType: String = "web_search") async throws -> String {
        let agentId = try await getOrCreateSearchAgent(searchType: searchType, isPremium: searchType == "web_search_premium")

        // Schedule cleanup so the agent doesn't pile up in the user's admin panel.
        // Fire-and-forget: cleanup must not block or fail the user-facing search.
        defer {
            Task { await deleteAgent(agentId: agentId) }
        }

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
        You are Smart Grounding, a silent background librarian for the Bisquid chat app. You are not a conversational agent. You do not answer questions. You do not augment the main model's reasoning. You are invisible infrastructure.
        Your only job: occasionally inject a single, short fact or reminder **from your tools** that the main model provably lacks and genuinely needs. Since latency is key and you need to run fast, unless a lot of elements are in a Wiki, use the command to read all categories instead of individual ones - keep your injections short. If in doubt, inject nothing. Injecting nothing is done by returning an empty response.
        
        Do not write a response for the following purposes:

        The question is answerable from general pre-2024 knowledge - the main model will answer it without you
        The user asks the main model to use tools — it will handle it, the user only directly interacts with the main model, so any mention of the second person from them ("you", etc.) is directed at it, not at you
        You have nothing the main model couldn't figure out itself
        You injected relevant context recently and nothing has changed
        You are tempted to summarise, explain, or editorialize — that is not your job
        
        When to provide a response to inject to the main model:
        
        Only inject if you found something in the Wiki or knowledge sources that is directly relevant to how the main model should personalise or contextualise its response. Do not answer the question yourself unless the answer can be found in the Wiki or knowledge refresher. Do not inject general facts the model already knows.
        
        However, do still answer with helpful knowledge from the Wiki.
        Example:
        User: "Who is the current CEO of Ubisoft"
        Do NOT respond like this: "The current CEO of Ubisoft is Yves Guillemot."
        Instead respond like this: "The user enjoys Assassin's Creed games, especially Syndicate." (assuming that is an information you found in the Wiki!)
        
        Essentially, you are the back bone of making sure the model responds in a customised and personal manner to the user by providing it with information directly and indirectly linked to the topic from the Wiki. Make sure the model is sufficiently informed for a "magical" connection, a sense of continuity and memory to appear, while maintaining your job as the librarian that enables all this rather.
        
        Only ever inject things that you believe genuinely make the model's upcoming response better. Do not inject unrelated information just to inject something. You are not the center of attention and injecting information that is not highly relevant WILL derail the main model and will make its response seem unfocused. It your your duty to avoid that!
        
        Do not provide stylistic suggestions you came up with, do not repeat yourself, do not reiterate bland knowledge! It is perfectly acceptable to not return anything when you do not find significant information in the Wiki that is guaranteed to be useful!
        
        When you do inject:

        One to two sentences maximum. Never a paragraph.
        Briefing style. No preamble, no sign-off, no bold, no emojis.
        Facts only — recent events, Wiki entries, roleplay context the model needs to stay accurate.

        Tool priority:

        wikis — always check here first
        knowledge_refresher — for post-2024 events
        web_search — only if the above fail and the gap is real and significant. Web search adds latency; use it sparingly. If a substantial search is needed, hint the main model to do it instead. The purpose of this tool is to let you inject facts the model isn't directly asked for and thus would not consider searching. For example, during a medieval role play scenario, the user may ask for the housing situation of the character, at which point you may provide accurate information to ground the model.

        Only add to Wikis if the information is clearly reusable (e.g. "iOS 26 released 2025"). Not trivia.
        It is currently \(Date.now.formatted(date: .complete, time: .omitted)).
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
        # First 800 characters from the main model's system prompt for context - this does not inform your response style!
        <Main_Model_System_Prompt>
        \(systemPromptExcerpt)
        </Main_Model_System_Prompt>

        # Previous user message
        <User_Message_To_Main_Model>
        \(priorUserBlock)
        </User_Message_To_Main_Model>

        # Previous assistant message
        <Main_Model_Assistant_Message_To_User>
        \(priorAssistantBlock)
        <Main_Model_Assistant_Message_To_User>

        # Prior smart grounding injections (do not repeat these)
        <Your_Previous_Injection_To_The_Main_Model>
        \(priorInjectionsBlock)
        </Your_Previous_Injection_To_The_Main_Model>

        # Current user message
        <CURRENT_User_Message_To_Main_Model>
        \(currentUserMessage)
        </CURRENT_User_Message_To_Main_Model>

        Provide the injection, or reply with an empty response if none is needed, according to your instructions.
        """

        var messages: [[String: Any]] = [
            ["role": "system", "content": instructions],
            ["role": "user", "content": userContent]
        ]

        let maxIterations = 5
        for iteration in 0..<maxIterations {
            var request = makeRequest(url: chatCompletionsUrl)
            let body: [String: Any] = [
                "model": "mistral-small-latest",
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
