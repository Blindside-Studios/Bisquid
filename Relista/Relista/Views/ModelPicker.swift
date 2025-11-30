//
//  ModelPicker.swift
//  Relista
//
//  Created by Nicolas Helbig on 09.11.25.
//

import SwiftUI

struct ModelPicker: View {
    @Binding var selectedModelSlug: String
    @Binding var isOpen: Bool

    var body: some View {
        ScrollView(.vertical){
            ForEach(ModelList.AllModels){ model in
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
                .background(selectedModelSlug == model.modelID ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(.clear))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedModelSlug = model.modelID
                    isOpen = false
                }
            }
            .padding(8)
        }
    }
}

#Preview {
    ModelPicker(selectedModelSlug: .constant("mistral-medium-latest"), isOpen: .constant(true))
}
