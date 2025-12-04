//
//  SearchButton.swift
//  Relista
//
//  Created by Nicolas Helbig on 04.12.25.
//

import SwiftUI

struct SearchButton: View {
    @Binding var useSearch: Bool
    
    var body: some View {
        Button{
            useSearch.toggle()
        } label: {
            Label {
                Group {
                    if useSearch {
                        Text("Search")
                            .offset(x: -4)
                            .foregroundStyle(.blue)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .opacity
                            ))
                    } else {
                        Color.clear
                            .frame(width: 0, height: 0)    // truly zero width
                    }
                }
                //Text("Search")
                //    .opacity(useSearch ? 1 : 0)
                //    .scaleEffect(useSearch ? 1 : 0.8)
                //    .offset(x: useSearch ? 0 : -30)
                //    .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: useSearch)
            } icon: {
                Image(systemName: "globe")
                    .foregroundStyle(useSearch ? .blue : .primary)
                    #if os(macOS)
                    .offset(y: useSearch ? -0.5 : 0)
                    #endif
            }
            //.padding(useSearch ? 4 : 2)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(useSearch ? 0.15 : 0.0001))
                    .padding(useSearch ? -3 : 4)
            }
            // the following two lines to eliminate the gap to the right because the system thinks a label text is being displayed
            .padding(.horizontal, !useSearch ? -4 : 0)
            .offset(x: !useSearch ? 4 : 0)
            .animation(.bouncy(duration: 0.3, extraBounce: 0.05), value: useSearch)
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    SearchButton(useSearch: .constant(false))
}
