//
//  MemoryListEditor.swift
//  Relista
//
//  Created by Nicolas Helbig on 28.02.26.
//

import SwiftUI

/// A reusable list editor for an array of memory strings.
/// Designed to be used inside a Form Section.
///
/// `storageID` namespaces the `@SceneStorage` keys so that multiple
/// instances in the same scene (e.g. Personalization + Agent editor) don't
/// trample each other's sheet state.
struct MemoryListEditor: View {
    @Binding var memories: [String]

    @SceneStorage private var showAddSheet: Bool
    @SceneStorage private var editingIndex: Int
    @SceneStorage private var draftText: String

    init(memories: Binding<[String]>, storageID: String) {
        self._memories = memories
        self._showAddSheet = SceneStorage(wrappedValue: false, "memory.\(storageID).showAdd")
        self._editingIndex = SceneStorage(wrappedValue: -1, "memory.\(storageID).editingIndex")
        self._draftText = SceneStorage(wrappedValue: "", "memory.\(storageID).draftText")
    }

    private var isEditingBinding: Binding<Bool> {
        Binding(
            get: { editingIndex >= 0 },
            set: { if !$0 { editingIndex = -1 } }
        )
    }

    var body: some View {
        ForEach(memories.indices, id: \.self) { index in
            HStack {
                Button(action: {
                    draftText = memories[index]
                    editingIndex = index
                }) {
                    Text(memories[index])
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                Button(role: .destructive, action: {
                    memories.remove(at: index)
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
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
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: isEditingBinding) {
            if editingIndex >= 0 && editingIndex < memories.count {
                let index = editingIndex
                MemoryEditSheet(text: $draftText, title: "Edit Memory") {
                    let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { memories[index] = trimmed }
                }
                .interactiveDismissDisabled()
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
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        onSave()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
