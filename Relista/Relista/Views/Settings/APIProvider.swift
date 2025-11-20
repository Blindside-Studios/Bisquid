//
//  APIProvider.swift
//  Relista
//
//  Created by Nicolas Helbig on 20.11.25.
//

import SwiftUI

struct APIProvider: View {
    @AppStorage("APIKeyMistral") private var apiKey: String = ""
    
    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("Mistral API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
        }
    }
}

#Preview {
    APIProvider()
}
