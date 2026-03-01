//
//  GeneralSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 30.11.25.
//

import SwiftUI

struct GeneralSettings: View {
    #if os(macOS)
    @AppStorage("AddPaddingToTypingBar") private var typingBarPaddingMacOS: Bool = true
    #endif
    @AppStorage("ShowUserMessageToolbars") private var showUserMessageToolbars: Bool = false
    @AppStorage("AlwaysShowFullModelMessageToolbar") private var alwaysShowFullModelMessageToolbar: Bool = false
    #if os(iOS)
    @AppStorage("HapticFeedbackForMessageGeneration") private var vibrateOnTokensReceived: Bool = true
    #endif
    
    var body: some View {
        List{
            Section(header: Text("Response Display"), footer: Text("Only applies to bigger screens where information is displayed in-line")){
                Toggle("Show user message toolbars", isOn: $showUserMessageToolbars)
                Toggle("Always show time and model", isOn: $alwaysShowFullModelMessageToolbar)
            }
            
            // haptic feedback only applies to iPhone
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                Section(header: Text("Haptic Feedback")){
                    Toggle("Haptic feedback during response generation", isOn: $vibrateOnTokensReceived)
                }
            }
            #elseif os(macOS)
                Toggle("Add extra padding to the input bar", isOn: $typingBarPaddingMacOS)
            #endif
        }
    }
}

#Preview {
    GeneralSettings()
}
