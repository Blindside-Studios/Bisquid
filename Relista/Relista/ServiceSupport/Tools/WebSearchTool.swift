//
//  WebSearchTool.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import Foundation

struct WebSearchTool: ChatTool {
    var name: String { "web_search" }
    var displayName: String { "Web Search" }
    var description: String { "Search the web for current information" }
    var icon: String { "globe" }
    var defaultEnabled: Bool { true }

    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "web_search",
                "description": """
                Search the web for current information using a Mistral web search agent.
                You will receive a natural language answer with cited sources.

                Search type guide:
                - web_search (DEFAULT): Standard web search. Use for most queries - general knowledge, recent events, documentation, facts. 
                - web_search_premium: A more complex web search tool that in addition to a search engine enables access to news articles via integrated news provider verification. Use for breaking news, in-depth research, complex multi-faceted topics, or when standard search may miss relevant sources. Also prefer this for sensitive topics such as geopolitical news and discussion about political and military conflicts.

                Default to web_search unless the query clearly warrants premium coverage, you performed a web_search and it did not yield satisfactory results or specified in the request, your system instructions or memory.
                If you are using web_search and it does not return satisfactory results, before performing web_search_premium, explain that you are about to do that to the user to avoid confusion about multiple tool calls.  
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "The search query"
                        ],
                        "search_type": [
                            "type": "string",
                            "description": "The search tier to use. Defaults to web_search if omitted.",
                            "enum": ["web_search", "web_search_premium"]
                        ]
                    ],
                    "required": ["query"]
                ]
            ]
        ]
    }

    func inputSummary(from arguments: [String: Any]) -> String {
        let query = arguments["query"] as? String ?? "Searching…"
        if arguments["search_type"] as? String == "web_search_premium" {
            return "\(query) (premium)"
        }
        return query
    }

    func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw NSError(domain: "WebSearchTool", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing required argument: query"
            ])
        }
        let searchType = arguments["search_type"] as? String ?? "web_search"
        let agents = MistralAgents(apiKey: KeychainHelper.shared.mistralAPIKey)
        return try await agents.executeSearch(query: query, searchType: searchType)
    }
}
