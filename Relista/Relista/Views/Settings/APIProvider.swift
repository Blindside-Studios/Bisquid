//
//  APIProvider.swift
//  Relista
//
//  Created by Nicolas Helbig on 20.11.25.
//

import SwiftUI

struct APIProvider: View {
    @State private var apiKeyMistral: String = KeychainHelper.shared.mistralAPIKey
    @State private var apiKeyClaude: String = KeychainHelper.shared.claudeAPIKey
    @State private var apiKeyOpenRouter: String = KeychainHelper.shared.openRouterAPIKey

    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("Mistral API Key", text: $apiKeyMistral)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKeyMistral) { _, newValue in
                        KeychainHelper.shared.mistralAPIKey = newValue
                    }
                SecureField("Claude API Key", text: $apiKeyClaude)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKeyClaude) { _, newValue in
                        KeychainHelper.shared.claudeAPIKey = newValue
                    }
                /*SecureField("OpenRouter API Key", text: $apiKeyOpenRouter)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKeyOpenRouter) { _, newValue in
                        KeychainHelper.shared.openRouterAPIKey = newValue
                    }*/
            }
            .padding()
        }
    }
}

#Preview {
    APIProvider()
}
