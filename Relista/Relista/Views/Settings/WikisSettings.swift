//
//  WikisSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 21.04.26.
//

import SwiftUI

struct WikisSettings: View {
    @ObservedObject private var settings = SyncedSettings.shared

    @SceneStorage("wikis.showAdd") private var showAdd: Bool = false
    @SceneStorage("wikis.draftCategory") private var draftCategory: String = ""
    @SceneStorage("wikis.draftContent") private var draftContent: String = ""

    private var categories: [String] {
        Array(Set(settings.wikiEntries.map(\.category))).sorted()
    }

    var body: some View {
        Form {
            if categories.isEmpty {
                Section {
                    Text("No knowledge entries yet. Add one below, or let a model do it for you.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(categories, id: \.self) { category in
                Section(category) {
                    MemoryListEditor(
                        memories: binding(for: category),
                        storageID: "wikis.\(category)"
                    )
                }
            }

            Section {
                Button {
                    draftCategory = ""
                    draftContent = ""
                    showAdd = true
                } label: {
                    Label("Add Knowledge", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAdd) {
            AddWikiSheet(category: $draftCategory, content: $draftContent) {
                let cat = draftCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                let text = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cat.isEmpty && !text.isEmpty {
                    settings.wikiEntries.append(WikiEntry(category: cat, content: text))
                }
            }
            .interactiveDismissDisabled()
        }
    }

    /// Projects the subset of `wikiEntries` belonging to `category` as a
    /// `Binding<[String]>` so `MemoryListEditor` can drive edits. Mutations
    /// made by the editor (edit-in-place, remove-at, remove-atOffsets, append)
    /// are diffed back into the source array.
    private func binding(for category: String) -> Binding<[String]> {
        Binding(
            get: { settings.wikiEntries.filter { $0.category == category }.map(\.content) },
            set: { newContents in
                var entries = settings.wikiEntries
                let sourceIndices = entries.indices.filter { entries[$0].category == category }

                if newContents.count == sourceIndices.count {
                    // Edit in place
                    for (i, srcIdx) in sourceIndices.enumerated()
                        where entries[srcIdx].content != newContents[i] {
                        entries[srcIdx].content = newContents[i]
                    }
                } else if newContents.count > sourceIndices.count {
                    // Edits plus appends at the end
                    for (i, srcIdx) in sourceIndices.enumerated()
                        where entries[srcIdx].content != newContents[i] {
                        entries[srcIdx].content = newContents[i]
                    }
                    for i in sourceIndices.count..<newContents.count {
                        entries.append(WikiEntry(category: category, content: newContents[i]))
                    }
                } else {
                    // Removals: match remaining contents in order and drop the rest.
                    var iter = newContents.makeIterator()
                    var next = iter.next()
                    var kept = Set<Int>()
                    for srcIdx in sourceIndices {
                        if let n = next, entries[srcIdx].content == n {
                            kept.insert(srcIdx)
                            next = iter.next()
                        }
                    }
                    entries = entries.enumerated().compactMap { (i, e) in
                        (e.category == category && !kept.contains(i)) ? nil : e
                    }
                }

                settings.wikiEntries = entries
            }
        )
    }
}

private struct AddWikiSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var category: String
    @Binding var content: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Category", text: $category, prompt: Text("Category"))
                        .labelsHidden()
                }
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Knowledge")
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
                    .disabled(
                        category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}

#Preview {
    WikisSettings()
}
