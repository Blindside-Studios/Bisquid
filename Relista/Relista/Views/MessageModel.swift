//
//  MessageModel.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct MessageModel: View {
    let messageText: String
    
    var body: some View {
        HStack {
            Text(messageText)
                .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

#Preview {
    MessageModel(messageText: "User message")
}
