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
                TextField("Default instructions", text: $settings.defaultInstructions, axis: .vertical)
                    .lineLimit(5...)
            }
            
            Section("Memories") {
                MemoryListEditor(memories: $settings.memories, storageID: "personalization")
            }
            
            Section("Default Temperature") {
                Slider(value: $settings.temperature, in: 0...1)
                Text(settings.temperature, format: .number.precision(.fractionLength(2)))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            
            Section("Modifications"){
                Toggle("Replace em-dashes with en-dashes", isOn: $settings.suppressEmDashes)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    PersonalizationSettings()
}
