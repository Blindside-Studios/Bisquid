//
//  PersonalizationSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 03.12.25.
//

import SwiftUI

struct PersonalizationSettings: View {
    @ObservedObject private var settings = SyncedSettings.shared

    var body: some View {
        Form {
            Section("Personal info") {
                TextField("Name", text: $settings.userName)
            }
            Section("Default Model") {
                ModelPicker(selectedModel: $settings.defaultModel)
            }

            Section("Default instructions") {
                TextEditor(text: $settings.defaultInstructions)
                    .frame(minHeight: 150)
            }
        }
    }
}

#Preview {
    PersonalizationSettings()
}
