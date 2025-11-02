//
//  MessageUser.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct MessageUser: View {
    let messageText: String
    let availableWidth: CGFloat
    
    var body: some View {
        HStack {
            Spacer(minLength: availableWidth * 0.2)
            
            Text(messageText)
                .padding()
                .glassEffect(in: .rect(cornerRadius: 25.0))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal)
    }
}

#Preview {
    MessageUser(messageText: "Assistant message", availableWidth: 200)
}
