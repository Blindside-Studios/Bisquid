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
    
    let family: String?
    let specifier: String?
}

class ModelList{
    static let Models: [AIModel] = [
        AIModel(name: "Mistral Medium",   modelID: "mistral-medium-latest",   provider: .mistral, family: "Mistral",   specifier: "Medium"),
        AIModel(name: "Magistral Medium", modelID: "magistral-medium-latest", provider: .mistral, family: "Magistral", specifier: "Medium"),
        AIModel(name: "Mistral Small",    modelID: "mistral-small-latest",    provider: .mistral, family: "Mistral",   specifier: "Small"),
        AIModel(name: "Magistral Small",  modelID: "magistral-small-latest",  provider: .mistral, family: "Magistral", specifier: "Small"),
        AIModel(name: "Mistral Large",    modelID: "mistral-large-latest",    provider: .mistral, family: "Mistral",   specifier: "Large"),

        AIModel(name: "Codestral",        modelID: "codestral-latest",        provider: .mistral, family: nil,         specifier: nil),
        AIModel(name: "Mistral NeMo",     modelID: "open-mistral-nemo",       provider: .mistral, family: "Mistral",   specifier: "NeMo"),
        AIModel(name: "Mistral 7B",       modelID: "open-mistral-7b",         provider: .mistral, family: "Mistral",   specifier: "7B"),

        AIModel(name: "Mixtral 8x7B",     modelID: "open-mixtral-8x7b",       provider: .mistral, family: "Mixtral",   specifier: "8x7B"),
        AIModel(name: "Mixtral 8x22B",    modelID: "open-mixtral-8x22b",      provider: .mistral, family: "Mixtral",   specifier: "8x22B"),

        AIModel(name: "Ministral 8B",     modelID: "ministral-8b-latest",     provider: .mistral, family: "Ministral", specifier: "8B"),
        AIModel(name: "Ministral 3B",     modelID: "ministral-3b-latest",     provider: .mistral, family: "Ministral", specifier: "3B")
    ]
}
