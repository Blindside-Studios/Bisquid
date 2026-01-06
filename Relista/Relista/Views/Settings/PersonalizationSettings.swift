//
//  PersonalizationSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 03.12.25.
//

import SwiftUI

struct PersonalizationSettings: View {
    @AppStorage("AppDefaultModel") private var defaultModel: String = "mistralai/mistral-medium-3.1"
    @AppStorage("DefaultAssistantInstructions") private var sysInstructions: String = ""
    @AppStorage("UIUserName") private var userName: String = ""
    
    var body: some View {
        Form{
            Section("Personal info"){
                TextField("Name", text: $userName)
            }
            Section("Default Model"){
                ModelPicker(selectedModel: $defaultModel)
            }
            
            Section("Default instructions"){
                TextEditor(text: $sysInstructions)
                    .frame(minHeight: 150)
            }
        }
    }
}

#Preview {
    PersonalizationSettings()
}
