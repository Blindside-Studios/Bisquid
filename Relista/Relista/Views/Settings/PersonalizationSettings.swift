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
                TextField("Name", text: $settings.userName, prompt: Text("Name"))
                    .labelsHidden()
            }

            Section("Default instructions") {
                TextField("Default instructions", text: $settings.defaultInstructions, prompt: Text("Default instructions"), axis: .vertical)
                    .lineLimit(5...)
                    .labelsHidden()
            }
            
            Section("Default Model") {
                HStack {
                    ModelPicker(selectedModel: $settings.defaultModel)
                    VStack(alignment: .leading) {
                        Text("Temperature: " +  String(format: "%.2f", settings.temperature))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                        Slider(value: $settings.temperature, in: 0...1, step: 0.05)
                    }
                }
            }
            
            Section("Memories") {
                MemoryListEditor(memories: $settings.memories, storageID: "personalization")
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
