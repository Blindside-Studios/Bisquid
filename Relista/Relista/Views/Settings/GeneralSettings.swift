//
//  GeneralSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 30.11.25.
//

import SwiftUI

struct GeneralSettings: View {
    @AppStorage("AlwaysShowFullModelMessageToolbar") private var alwaysShowFullModelMessageToolbar: Bool = false
    @AppStorage("HapticFeedbackForMessageGeneration") private var vibrateOnTokensReceived: Bool = true
    
    var body: some View {
        List{
            Section(header: Text("Info"), footer: Text("Only applies to bigger screens where information is displayed in-line")){
                Toggle("Always show time and model", isOn: $alwaysShowFullModelMessageToolbar)
            }
            
            // haptic feedback only applies to iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                Section(header: Text("Haptic Feedback")){
                    Toggle("Haptic feedback during response generation", isOn: $vibrateOnTokensReceived)
                }
            }
        }
    }
}

#Preview {
    GeneralSettings()
}
