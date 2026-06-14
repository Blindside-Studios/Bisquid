//
//  PencilKitInputUI.swift
//  Bisquid
//
//  Created by Nicolas Helbig on 13.06.26.
//

#if os(iOS)
import SwiftUI
import PencilKit

struct PencilKitInputUI: View {
    @State var showModelPickerSheet = false
    @State var showModelPickerPopOver = false
    @Binding var conversationID: UUID
    @Binding var inputMessage: String
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    @State private var chatCache = ChatCache.shared
    @State private var placeHolder = ChatPlaceHolders.returnRandomString()

    @Binding var primaryAccentColor: Color
    @Binding var secondaryAccentColor: Color
    @Binding var editingMessage: Message?
    @Binding var pendingAttachments: [PendingAttachment]
    var inputFieldNamespace: Namespace.ID
    @State private var textFieldFocusRequest: Bool = false
    @State private var canvasView = PKCanvasView()
    @State var userPenSelection: String = "pen"
    
    @AppStorage("HapticFeedbackForMessageGeneration") private var vibrateOnTokensReceived: Bool = true
    
    private var cornerRadius: Int{
        22
    }
    
    private var liquidGlassTint: Color{
        switch (colorScheme, inputMessage.isEmpty) {
            // YOU CAN HAVE MULTIPLE PROPERTIES IN A SWITCH STATEMENT?! Absolute cinema
            case (.dark, true):  return Color.black.opacity(0)
            case (.dark, false): return Color.black.opacity(0.7)
            case (_, true):      return Color.black.opacity(0.1)
            case (_, false):     return Color.white.opacity(0.7)
        }
    }

    var body: some View {
        let spacing: CGFloat = 16
        HStack{
            VStack(alignment: .leading, spacing: spacing) {
                if editingMessage != nil {
                    HStack(spacing: 8) {
                        Text("Sending will restart the conversation from this message")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            withAnimation(.bouncy(duration: 0.3)) {
                                editingMessage = nil
                                inputMessage.removeAll()
                                pendingAttachments = []
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    Divider()
                }
                if !pendingAttachments.isEmpty {
                    PendingImageStrip(pendingAttachments: $pendingAttachments)
                        .transition(.blurFade.combined(with: .opacity))
                }
                
                PencilKitInputField(canvasView: $canvasView, userPenSelection: $userPenSelection)
                    .zIndex(1)
                //.padding(spacing)
            }
            VStack(alignment: .center, spacing: 16){
                VStack(alignment: .center, spacing: 8){
                    Button("Pen", systemImage: "pencil"){
                        userPenSelection = "pen"
                    }
                    .background(){
                        if userPenSelection == "pen"{
                            Circle().fill(.blue).scaleEffect(2)
                        }
                    }
                    Button("Eraser", systemImage: "pencil.slash"){
                        userPenSelection = "eraser"
                    }
                    .background(){
                        if userPenSelection == "eraser"{
                            Circle().fill(.blue).scaleEffect(2)
                        }
                    }
                    Button("Selection", systemImage: "pencil.and.outline"){
                        userPenSelection = "selection"
                    }
                    .background(){
                        if userPenSelection == "selection"{
                            Circle().fill(.blue).scaleEffect(2)
                        }
                    }
                    Spacer()
                }
                .offset(x: 8)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                Spacer()
                CommandBar(isVertical: true, selectedModel: $selectedModel, conversationID: $conversationID, secondaryAccentColor: $secondaryAccentColor, pendingAttachments: $pendingAttachments, sendMessage: sendMessage, sendMessageAsSystem: sendMessageAsSystem, appendDummyMessages: appendDummyMessages, inputFieldNamespace: inputFieldNamespace)
            }
            //.frame(width: 70)
        }
        .frame(height: 300)
        .animation(.bouncy(duration: 0.3), value: pendingAttachments.isEmpty)
        .animation(.bouncy(duration: 0.3), value: editingMessage == nil)
        .padding(spacing)
        .glassEffect(.regular, in: .rect(cornerRadius: CGFloat(cornerRadius)))
        .padding(8)
        // Drag & drop: pass through the image framework so HEIC and any other
        // OS-decodable format is accepted and normalized to JPEG.
        .dropDestination(for: Data.self) { items, _ in
            let attachments = items.compactMap { normalizedAttachment(from: $0) }
            guard !attachments.isEmpty else { return false }
            withAnimation(.bouncy(duration: 0.3)) { pendingAttachments.append(contentsOf: attachments) }
            return true
        }
        .onChange(of: selectedAgent, refreshPlaceHolder)
        .onChange(of: editingMessage) { _, newValue in
            guard let msg = newValue else { return }
            inputMessage = msg.text
            let attachments = msg.attachmentLinks.compactMap { filename -> PendingAttachment? in
                guard let data = AttachmentManager.loadImage(filename: filename, for: conversationID) else { return nil }
                let ext = (filename as NSString).pathExtension.isEmpty ? "jpg" : (filename as NSString).pathExtension
                return PendingAttachment(data: data, fileExtension: ext)
            }
            withAnimation(.bouncy(duration: 0.3)) {
                pendingAttachments = attachments
            }
        }
        .matchedGeometryEffect(id: "inputField", in: inputFieldNamespace)
    }

    // MARK: - Image normalization helpers

    /// Decodes image data through the OS image framework (handles JPEG, PNG, GIF, WebP,
    /// HEIC, TIFF, BMP, etc.) and re-encodes to JPEG for consistent Pixtral compatibility.
    /// Returns nil if the data is not a recognized image format.
    private func normalizedAttachment(from data: Data) -> PendingAttachment? {
        guard let ui = UIImage(data: data),
              let jpeg = ui.jpegData(compressionQuality: 0.9) else { return nil }
        return PendingAttachment(data: jpeg, fileExtension: "jpg")
    }

    func sendMessage(){
        let apiKey = KeychainHelper.shared.mistralAPIKey
        
        let chat = chatCache.getChat(for: conversationID)
        if !chat.isGenerating {
            placeHolder = ChatPlaceHolders.returnAppropriatePlaceholder(agentUUID: selectedAgent)
            if (inputMessage != ""){
                // Dismiss software keyboard while keeping hardware keyboard functional
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                if vibrateOnTokensReceived {
                    let feedbackGenerator = UINotificationFeedbackGenerator()
                    feedbackGenerator.notificationOccurred(.success)
                }
                let input = inputMessage
                inputMessage = ""
                DispatchQueue.main.async {
                    // force render refresh to prevent a bug where the placeholder text isn't showing up and the blinking cursor disappears
                }
                
                // Capture and clear pending attachments before the async send
                let attachmentsToSend = pendingAttachments.map { ($0.data, $0.fileExtension) }
                pendingAttachments = []

                // If editing, truncate from the edited message onward before sending
                if let editing = editingMessage {
                    chatCache.truncateMessages(for: conversationID, from: editing.id)
                    editingMessage = nil
                }

                // Use ChatCache to send message and handle generation
                chatCache.sendMessage(
                    modelName: selectedModel,
                    agent: selectedAgent,
                    inputText: input,
                    to: conversationID,
                    apiKey: apiKey,
                    withHapticFeedback: vibrateOnTokensReceived,
                    tools: ToolRegistry.enabledTools(for: selectedAgent, conversationID: conversationID),
                    attachments: attachmentsToSend
                )
            }
        }
    }

    func sendMessageAsSystem(){
        let chat = chatCache.getChat(for: conversationID)
        if !chat.isGenerating{
            placeHolder = ChatPlaceHolders.returnAppropriatePlaceholder(agentUUID: selectedAgent)
            if (inputMessage != ""){
                // Dismiss software keyboard while keeping hardware keyboard functional
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                if vibrateOnTokensReceived {
                    let feedbackGenerator = UINotificationFeedbackGenerator()
                    feedbackGenerator.notificationOccurred(.warning)
                }
                let input = inputMessage
                inputMessage = ""
                DispatchQueue.main.async {
                }
                
                chatCache.sendMessageAsSystem(inputText: input, to: conversationID)
            }
        }
    }
    
    func appendDummyMessages(){
        
    }
    
    func refreshPlaceHolder(){
        placeHolder = ChatPlaceHolders.returnAppropriatePlaceholder(agentUUID: selectedAgent)
    }
}

struct PKCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
#endif
