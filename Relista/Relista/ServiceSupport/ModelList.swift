//
//  ModelList.swift
//  Relista
//
//  Created by Nicolas Helbig on 15.11.25.
//

import Foundation

enum ModelProvider: String, CaseIterable{
    case openAI = "OpenAI"
    case mistral = "Mistral"
    case anthropic = "Anthropic"
    case perplexity = "Perplexity"
}

struct AIModel: Identifiable, Hashable{
    let id = UUID()
    let name: String
    let modelID: String
    let provider: ModelProvider
}

class ModelList{
    static let Models: [AIModel] = [
        AIModel(name: "Mistral Medium", modelID: "mistral-medium-latest", provider: .mistral),
        AIModel(name: "Magistral Medium", modelID: "magistral-medium-latest", provider: .mistral),
        AIModel(name: "Mistral Small", modelID: "mistral-small-latest", provider: .mistral),
        AIModel(name: "Magistral Small", modelID: "magistral-small-latest", provider: .mistral),
        AIModel(name: "Mistral Large", modelID: "mistral-large-latest", provider: .mistral),
        AIModel(name: "Codestral", modelID: "codestral-latest", provider: .mistral),
        AIModel(name: "Mistral NeMo", modelID: "open-mistral-nemo", provider: .mistral),
        AIModel(name: "Mistral 7B", modelID: "open-mistral-7b", provider: .mistral),
        AIModel(name: "Mixtral 8x7B", modelID: "open-mixtral-8x7b", provider: .mistral),
        AIModel(name: "Mixtral 8x22B", modelID: "open-mixtral-8x22b", provider: .mistral),
        AIModel(name: "Ministral 8B", modelID: "ministral-8b-latest", provider: .mistral),
        AIModel(name: "Ministral 3B", modelID: "ministral-3b-latest", provider: .mistral)
        ]
}
