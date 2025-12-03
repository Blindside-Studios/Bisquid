//
//  PersonalizationSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 03.12.25.
//

import SwiftUI

struct PersonalizationSettings: View {
    @AppStorage("AppDefaultModel") private var defaultModel: String = "mistralai/mistral-medium-3.1"
    @State private var showModelPickerPopOver = false
    @AppStorage("DefaultAssistantInstructions") private var sysInstructions: String = ""
    
    var body: some View {
        Form{
            Section("Default Model"){
                Text(defaultModel)
                    .popover(isPresented: $showModelPickerPopOver) {
                        ModelPicker(
                            selectedModelSlug: $defaultModel,
                            isOpen: $showModelPickerPopOver
                        )
                        .frame(minWidth: 250, maxHeight: 450)
                        .presentationCompactAdaptation(.popover)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture{ showModelPickerPopOver.toggle() }
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
