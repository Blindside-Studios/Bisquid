//
//  InputUI.swift
//  Relista
//
//  Created by Nicolas Helbig on 06.01.26.
//

import SwiftUI

struct InputUI: View {
    // pass-through
    @Binding var conversationID: UUID
    @Binding var inputMessage: String
    @Binding var selectedAgent: UUID?
    @Binding var selectedModel: String
    @Binding var primaryAccentColor: Color
    @Binding var secondaryAccentColor: Color
    @Binding var editingMessage: Message?
    @Binding var pendingAttachments: [PendingAttachment]
    
    // own logic
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #if os(macOS)
    @Environment(\.controlActiveState) private var focused
    #endif
    private var isChatBlank: Bool{
        ChatCache.shared.loadedChats[conversationID]?.messages.isEmpty ?? false
    }
    private var agentIcon: String{
        if selectedAgent != nil{
            AgentManager.getUIAgentImage(fromUUID: selectedAgent!)
        } else {
            "🐙"
        }
    }
    @State private var greetingBannerText: String = ""
    @State private var displayedGreeting: String = ""
    @State private var greetingTask: Task<Void, Never>?
    
    #if os(macOS)
    @AppStorage("AddPaddingToTypingBar") private var typingBarPaddingMacOS: Bool = true
    #endif
    
    var body: some View {
        Group{
            if horizontalSizeClass == .compact {
                #if os(iOS)
                VStack (alignment: .center){
                    if isChatBlank{
                        VStack{
                            Spacer(minLength: 0)
                            Text(agentIcon)
                                .font(.system(size: 72))
                            Text(displayedGreeting)
                                .opacity(0.75)
                                .multilineTextAlignment(.center)
                                .font(.largeTitle)
                            Spacer(minLength: 0)
                            Spacer(minLength: 0)
                            Spacer(minLength: 0)
                        }
                        .padding()
                        .layoutPriority(0)
                        .transition(
                            AnyTransition.blurFade.combined(with: .offset(y: -150)).combined(with: .opacity)
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture().onEnded {
                            #if os(iOS)
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            #endif
                        })
                        NewChatAgentPicker(conversationID: $conversationID, selectedAgent: $selectedAgent, selectedModel: $selectedModel)
                            .layoutPriority(0)
                            .transition(
                                AnyTransition.blurFade.combined(with: .offset(y: 50)).combined(with: .opacity)
                            )
                            //.shadow(color: .black.opacity(isChatBlank ? 0.075 : 0.025), radius: 12)
                    }

                    PromptField(conversationID: $conversationID, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel, primaryAccentColor: $primaryAccentColor, secondaryAccentColor: $secondaryAccentColor, editingMessage: $editingMessage, pendingAttachments: $pendingAttachments)
                        .layoutPriority(1)
                        .shadow(color: .black.opacity(isChatBlank ? 0.075 : 0.025), radius: 12)
                }
                #endif
            } else {
                VStack{
                    if isChatBlank {
                        Spacer()

                        HStack(alignment: .bottom){
                            Spacer()
                            Text(agentIcon)
                            Text(displayedGreeting)
                                .opacity(0.85)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding()
                        .font(Font.largeTitle.bold())
                        .frame(height: 20, alignment: .bottom)
                        .transition(
                            AnyTransition.blurFade.combined(with: .offset(y: -150)).combined(with: .opacity)
                        )
                    }
                    PromptField(conversationID: $conversationID, inputMessage: $inputMessage, selectedAgent: $selectedAgent, selectedModel: $selectedModel, primaryAccentColor: $primaryAccentColor, secondaryAccentColor: $secondaryAccentColor, editingMessage: $editingMessage, pendingAttachments: $pendingAttachments)
                        #if os(macOS)
                        .padding(typingBarPaddingMacOS && !isChatBlank ? 16 : 0)
                        /*.shadow(color: focused == .inactive ? .clear : .black.opacity(isChatBlank ? 0.075 : 0.025), radius: focused == .inactive ? 0 : 12)
                        #else
                        .shadow(color: .black.opacity(isChatBlank ? 0.075 : 0.025), radius: 12)*/
                        #endif
                    if isChatBlank {
                        NewChatAgentPicker(conversationID: $conversationID, selectedAgent: $selectedAgent, selectedModel: $selectedModel)
                            .zIndex(-1) // to place it behind the PromptField, otherwise it would just constantly overlap and we couldn't click anything anymore
                            .transition(
                                AnyTransition.blurFade.combined(with: .offset(y: 350)).combined(with: .opacity)
                            )
                            #if os(macOS)
                            .shadow(color: focused == .inactive ? .clear : .black.opacity(isChatBlank ? 0.075 : 0.025), radius: focused == .inactive ? 0 : 12)
                            #else
                            .shadow(color: .black.opacity(0.075), radius: 12)
                            #endif
                        // double spacer so the actual content is above center
                        Spacer()
                        Spacer()
                    }
                }
                // center-alignment
                .frame(maxWidth: .infinity)
                .frame(maxWidth: 750)
                .frame(maxWidth: .infinity)
                //.contentMargins(.horizontal, 16, for: .scrollContent)
                .padding(.horizontal, isChatBlank ? 50 : 0)
                //.clipped()
                #if os(macOS)
                .animation(.default, value: typingBarPaddingMacOS)
                #endif
            }
        }
        .task(id: conversationID){
            greetingTask?.cancel()
            if !isChatBlank { return } // don't create a greeting when the user navigates to an actual chat
            
            displayedGreeting = ""
            
            do {
                greetingBannerText = try await Mistral(apiKey: KeychainHelper.shared.mistralAPIKey)
                    .generateGreetingBanner(agent: selectedAgent)
                
                greetingTask = Task {
                    await animateGreeting(greetingBannerText)
                }
            } catch {
                greetingBannerText = "Hello!"
                displayedGreeting = "Hello!"
            }
        }
        .animation(.bouncy, value: isChatBlank)
    }
    
    private func animateGreeting(_ fullText: String) async {
        displayedGreeting = ""
        
        for character in fullText {
            if Task.isCancelled { return }
            
            displayedGreeting.append(character)
            try? await Task.sleep(for: .milliseconds(30))
        }
    }
}

extension AnyTransition {
    static var blurFade: AnyTransition {
        .modifier(
            active: BlurModifier(radius: 30),
            identity: BlurModifier(radius: 0)
        )
    }
}

struct BlurModifier: ViewModifier {
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

#Preview {
    //InputUI()
}
