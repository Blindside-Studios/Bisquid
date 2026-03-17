//
//  ModelPicker.swift
//  Relista
//
//  Created by Nicolas Helbig on 13.12.25.
//

import SwiftUI

struct ModelPicker: View {
    @Namespace private var ModelPickerTransition
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var showModelPickerPopOver = false
    @State private var showModelPickerSheet = false
    
    @Binding var selectedModel: String
    @State private var internalModelRepresentation = ModelList.getModelFromSlug(slug: ModelList.placeHolderModel)
    private var display: [String]{
        switch(selectedModel){
        case "mistral-small-latest":
            return ["Mistral", "Small"]
        case "[t]mistral-small-latest":
            return ["Mistral Small", "Thinking"]
        case "mistral-medium-latest":
            return ["Mistral", "Medium"]
        case "[t]mistral-medium-latest":
            return ["Mistral Medium", "Thinking"]
        case "mistral-large-latest":
            return ["Mistral", "Large"]
        case "[t]mistral-large-latest":
            return ["Mistral Large", "Thinking"]
        default:
            if let family = internalModelRepresentation.family,
               let spec = internalModelRepresentation.specifier {
                return [family, spec]
            } else {
                return [internalModelRepresentation.name]
            }
        }
    }
    
    var body: some View {
        Button{
            if horizontalSizeClass == .compact { showModelPickerSheet = true }
            else { showModelPickerPopOver.toggle() }
        } label: {
            VStack(alignment: .center, spacing: -2) {
                if display.count > 1 {
                    Text(display[0])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(display[1])
                        .font(.caption)
                } else if display.count == 1 {
                    Text(display[0])
                        .font(.caption)
                } else {
                    Text("Model error")
                        .font(.caption)
                }
            }
            .bold()
            .onAppear(perform: refreshModelDisplay)
            .onChange(of: ModelList.areModelsLoaded, refreshModelDisplay)
            .onChange(of: selectedModel, refreshModelDisplay)
        }
        .buttonStyle(.plain)
        .labelStyle(.titleOnly)
        .matchedTransitionSource(
            id: "model", in: ModelPickerTransition
        )
        .popover(isPresented: $showModelPickerPopOver) {
            ModelPickerContents(
                selectedModelSlug: $selectedModel,
                isOpen: $showModelPickerPopOver
            )
            .presentationCompactAdaptation(.popover)
            .frame(width: 350, height: 400)
        }
        #if os(iOS)
        /// only show this on iOS because the other platforms use a popover,
        /// the differentiation exists such that we can use a matched gemoetry effect,
        /// which is not possible on popover and is much less possible on macOS anyways.
        .sheet(isPresented: $showModelPickerSheet) {
            ModelPickerContents(
                selectedModelSlug: $selectedModel,
                isOpen: $showModelPickerSheet
            )
            .presentationDetents([.medium, .large])
            .navigationTransition(
                .zoom(sourceID: "model", in: ModelPickerTransition)
            )
        }
        #endif
    }
    
    private func refreshModelDisplay(){
        internalModelRepresentation = ModelList.getModelFromSlug(slug: selectedModel)
    }
}

struct ModelPickerContents: View {
    @Binding var selectedModelSlug: String
    @Binding var isOpen: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var cornerRounding: CGFloat{
        if horizontalSizeClass == .compact{
            return 24
        } else {
            return 16
        }
    }
    var interfacePadding: CGFloat{
        if horizontalSizeClass == .compact{
            return 16.0
        } else {
            return 8.0
        }
    }
    var cardSpacing: CGFloat = 4.0

    var body: some View {
        GeometryReader{ geo in
            ScrollView(.vertical){
                VStack(spacing: 8){
                    let msRadii = RectangleCornerRadii(topLeading: cornerRounding, bottomLeading: 4, bottomTrailing: 4, topTrailing: 8)
                    let mstRadii = RectangleCornerRadii(topLeading: 4, bottomLeading: cornerRounding, bottomTrailing: 8, topTrailing: 4)
                    let mmRadii = RectangleCornerRadii(topLeading: 8, bottomLeading: 4, bottomTrailing: 4, topTrailing: 8)
                    let mmtRadii = RectangleCornerRadii(topLeading: 4, bottomLeading: 8, bottomTrailing: 8, topTrailing: 4)
                    let mlRadii = RectangleCornerRadii(topLeading: 8, bottomLeading: 4, bottomTrailing: 4, topTrailing: cornerRounding)
                    let mltRadii = RectangleCornerRadii(topLeading: 4, bottomLeading: 8, bottomTrailing: cornerRounding, topTrailing: 4)
                    
                    let models = ["mistral-small-latest", "mistral-medium-latest", "mistral-large-latest"]
                    let modelNames = ["Small", "Medium", "Large"]
                    let emoji = ["🐙", "🦑", "🐋"]
                    let radii = [msRadii, mmRadii, mlRadii, mstRadii, mmtRadii, mltRadii]
                    let modelColors = [Color.purple, Color.orange, Color.blue]
                    
                    let widthDistributions = [0.3, 0.4, 0.3]
                    
                    HStack(alignment: .center, spacing: cardSpacing) {
                        ForEach(models.indices, id: \.self) { index in
                            VStack(alignment: .center, spacing: cardSpacing){
                                HStack{
                                    Spacer()
                                    VStack(spacing: -2){
                                        Text(emoji[index])
                                            .font(.system(size: 38))
                                            .minimumScaleFactor(0.5)
                                        Spacer()
                                            .frame(height: 16)
                                        Text("Mistral")
                                            .font(.subheadline)
                                            .opacity(0.5)
                                            .minimumScaleFactor(0.5)
                                        Text(modelNames[index])
                                            .font(.title)
                                            .minimumScaleFactor(0.5)
                                    }
                                    .padding(.vertical, 12)
                                    Spacer()
                                }
                                .background{
                                    UnevenRoundedRectangle(cornerRadii: radii[index], style: .continuous)
                                        .fill(selectedModelSlug == models[index] ? modelColors[index].opacity(0.2) : .gray.opacity(0.2))
                                        .stroke(selectedModelSlug == models[index] ? modelColors[index].opacity(0.45) : .clear)
                                }
                                .onTapGesture{
                                    selectedModelSlug = models[index]
                                    //isOpen = false
                                }
                                
                                HStack{
                                    Spacer()
                                    Text("Thinking")
                                        .font(.subheadline)
                                        .opacity(0.7)
                                        .padding(.vertical, 16)
                                        .minimumScaleFactor(0.5)
                                    Spacer()
                                }
                                .background{
                                    UnevenRoundedRectangle(cornerRadii: radii[index + 3], style: .continuous)
                                        .fill(selectedModelSlug == "[t]\(models[index])" ? modelColors[index].opacity(0.2) : .gray.opacity(0.2))
                                        .stroke(selectedModelSlug == "[t]\(models[index])" ? modelColors[index].opacity(0.45) : .clear)
                                }
                                .onTapGesture{
                                    selectedModelSlug = "[t]\(models[index])"
                                    //isOpen = false
                                }
                            }
                            .frame(width: (geo.size.width - (cardSpacing * 2) - (interfacePadding * 2)) * widthDistributions[index])
                        }
                    }
                    
                    VStack(spacing: 0){
                        ForEach(ModelList.AllModels){ model in
                            HStack(alignment: .center){
                                VStack(alignment: .leading, spacing: 0.0) {
                                    Text(model.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(model.modelID)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if selectedModelSlug == model.modelID{
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.vertical, 8.0)
                            .padding(.horizontal, 12.0)
                            .background{
                                if selectedModelSlug == model.modelID{
                                    RoundedRectangle(cornerRadius: cornerRounding, style: .continuous)
                                        .fill(.gray.opacity(0.2))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedModelSlug = model.modelID
                                isOpen = false
                            }
                        }
                    }
                }
                .padding(interfacePadding)
            }
        }
    }
}

#Preview {
    //ModelPicker()
}
