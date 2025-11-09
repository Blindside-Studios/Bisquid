//
//  ModelPicker.swift
//  Relista
//
//  Created by Nicolas Helbig on 09.11.25.
//

import SwiftUI

struct ModelPicker: View {
    @Binding var selectedModel: String
    @Binding var selectedModelDisplay: String
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .padding()
    }
}

#Preview {
    ModelPicker(selectedModel: .constant("ministral-3b-latest"), selectedModelDisplay: .constant("Ministral 3B"))
}
