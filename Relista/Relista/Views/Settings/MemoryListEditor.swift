//
//  MemoryListEditor.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI

/// A reusable list editor for an array of memory strings.
/// Designed to be used inside a Form Section.
struct MemoryListEditor: View {
    @Binding var memories: [String]

    @State private var showAddSheet = false
    @State private var editingIndex: Int?
    @State private var draftText = ""

    var body: some View {
        ForEach(memories.indices, id: \.self) { index in
            Button(action: {
                draftText = memories[index]
                editingIndex = index
            }) {
                Text(memories[index])
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .onDelete { offsets in
            memories.remove(atOffsets: offsets)
        }

        Button(action: {
            draftText = ""
            showAddSheet = true
        }) {
            Label("Add Memory", systemImage: "plus")
        }
        .sheet(isPresented: $showAddSheet) {
            MemoryEditSheet(text: $draftText, title: "New Memory") {
                let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { memories.append(trimmed) }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingIndex != nil },
            set: { if !$0 { editingIndex = nil } }
        )) {
            if let index = editingIndex {
                MemoryEditSheet(text: $draftText, title: "Edit Memory") {
                    let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { memories[index] = trimmed }
                }
            }
        }
    }
}

private struct MemoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let title: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
