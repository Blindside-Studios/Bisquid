//
//  MessageAnnotation.swift
//  Relista
//
//  Created to support OpenRouter web search annotations
//

import Foundation

/// Represents a URL citation from web search results
struct URLCitation: Codable, Equatable {
    let url: String
    let title: String?
    let content: String?
    let startIndex: Int?
    let endIndex: Int?

    enum CodingKeys: String, CodingKey {
        case url, title, content
        case startIndex = "start_index"
        case endIndex = "end_index"
    }
}

/// Represents an annotation in a message (currently only URL citations)
struct MessageAnnotation: Codable, Equatable {
    let type: String
    let urlCitation: URLCitation?

    enum CodingKeys: String, CodingKey {
        case type
        case urlCitation = "url_citation"
    }
}
