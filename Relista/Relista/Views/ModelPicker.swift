//
//  ModelPicker.swift
//  Relista
//
//  Created by Nicolas Helbig on 09.11.25.
//

import SwiftUI

struct ModelPicker: View {
    @Binding var selectedModel: AIModel
    
    var body: some View {
        ScrollView(.vertical){
            ForEach(ModelList.Models){ model in
                HStack{
                    VStack(alignment: .leading, spacing: 0.0) {
                        Text(model.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(model.modelID)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 4.0)
                .padding(.horizontal, 8.0)
                .background(selectedModel == model ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(.clear))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedModel = model
                }
            }
            .padding(8)
        }
    }
}

#Preview {
    ModelPicker(selectedModel: .constant(AIModel(name: "Mistral Medium", modelID: "mistral-medium-latest", provider: .mistral)))
}
