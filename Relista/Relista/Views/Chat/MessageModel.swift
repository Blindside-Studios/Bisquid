//
//  MessageModel.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI
import Textual

struct MessageModel: View {
    let message: Message
    let isUsingPencilView: Bool
    let onRegenerate: () -> Void

    @AppStorage("AlwaysShowFullModelMessageToolbar") private var toolbarExpansionPreference: Bool = false
    @ObservedObject private var settings = SyncedSettings.shared
    @State private var isToolbarExpanded: Bool = false
    @State private var showInfoPopOver: Bool = false
    @State private var showRegenerateConfirmation: Bool = false
    @State private var showGroundingPopover: Bool = false
    @State private var showGroundingSheet: Bool = false

    @State private var copied = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var smartGroundingText: String? {
        guard let annotations = message.annotations else { return nil }
        let content = annotations
            .first(where: { $0.type == "smart_grounding" })?
            .urlCitation?
            .content
        guard let text = content, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }
    
    private var modelDisplayName: String{
        switch(message.modelUsed){
        case "mistral-small-latest":
            return "Mistral Small"
        case "[t]mistral-small-latest":
            return "Mistral Small (Thinking)"
        case "mistral-medium-latest":
            return "Mistral Medium"
        case "[t]mistral-medium-latest":
            return "Mistral Medium (Thinking)"
        case "mistral-large-latest":
            return "Mistral Large"
        case "[t]mistral-large-latest":
            return "Mistral Large (Thinking)"
        default:
            return ModelList.getModelFromSlug(slug: message.modelUsed).name
        }
    }
    
    private let pencilViewFontSize = 24.0

    private func displayMarkdown(_ text: String) -> String {
        let dashed = settings.suppressEmDashes ? text.spacingEmDashes() : text
        return dashed.escapingEmptyListMarkers()
    }

    private var copyableText: String {
        settings.suppressEmDashes ? message.text.spacingEmDashes() : message.text
    }
    
    var body: some View {
        VStack{
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    if let blocks = message.contentBlocks {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                            if !isUsingPencilView{
                                switch block {
                                case .text(let text):
                                    StructuredText(markdown: displayMarkdown(text),
                                                   patternOptions: .init(mathExpressions: true))
                                    .textual.textSelection(.enabled)
                                    .padding(.top, 8)
                                case .toolUse(let toolBlock):
                                    ToolUseView(toolBlock: toolBlock)
                                case .thinking(let thinkingBlock):
                                    ThinkingView(thinkingBlock: thinkingBlock)
                                }
                            } else {
                                switch block {
                                case .text(let text):
                                    StructuredText(markdown: displayMarkdown(text),
                                                   patternOptions: .init(mathExpressions: true))
                                    .textual.textSelection(.enabled)
                                    .font(.custom("Georgia", size: pencilViewFontSize))
                                    .padding(.top, 8)
                                case .toolUse(let toolBlock):
                                    ToolUseView(toolBlock: toolBlock)
                                        .font(.custom("Georgia", size: pencilViewFontSize))
                                case .thinking(let thinkingBlock):
                                    ThinkingView(thinkingBlock: thinkingBlock)
                                        .font(.custom("Georgia", size: pencilViewFontSize))
                                }
                            }
                        }
                    } else {
                        if !isUsingPencilView{
                            StructuredText(markdown: displayMarkdown(message.text),
                                           patternOptions: .init(mathExpressions: true))
                            .textual.textSelection(.enabled)
                        } else {
                            StructuredText(markdown: displayMarkdown(message.text),
                                           patternOptions: .init(mathExpressions: true))
                            .textual.textSelection(.enabled)
                            .font(.custom("Georgia", size: pencilViewFontSize))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.vertical, isUsingPencilView ? 24 : 8)
                
                Spacer()
            }
            HStack(spacing: 0) {
                if !message.text.isEmpty{
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(copyableText, forType: .string)
                        #else
                        UIPasteboard.general.string = copyableText
                        #endif
                        withAnimation {
                            copied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label("Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(width: 28, height: 28)
                            .padding(3)
                            .contentShape(Rectangle())
                            #if os(iOS)
                            .hoverEffect(.highlight)
                            #endif
                            .scaleEffect(0.8)
                    }
                    .disabled(copied)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    
                    Button {
                        showRegenerateConfirmation.toggle()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                            #if os(iOS)
                            .hoverEffect(.highlight)
                            #endif
                            .scaleEffect(0.8)
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    #if os(iOS)
                    .confirmationDialog("Regenerate this response?", isPresented: $showRegenerateConfirmation) {
                        Button("Regenerate", role: .destructive) {
                            onRegenerate()
                        }
                    } message: {
                        Text("Regenerating will delete this message and restart the chat from here")
                    }
                    #else
                    .popover(isPresented: $showRegenerateConfirmation) {
                        VStack{
                            Text("Regenerating will delete this message and restart the chat from here")
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                            Button("Regenerate") {
                                onRegenerate()
                            }
                        }
                        .frame(width: 250, height: 70)
                        .padding()
                    }
                    #endif

                    if let groundingText = smartGroundingText {
                        Button {
                            if horizontalSizeClass == .compact { showGroundingSheet = true }
                            else { showGroundingPopover = true }
                        } label: {
                            Label("Show smart grounding context", systemImage: "bolt")
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                                #if os(iOS)
                                .hoverEffect(.highlight)
                                #endif
                                .scaleEffect(0.8)
                        }
                        .buttonStyle(.plain)
                        .labelStyle(.iconOnly)
                        .popover(isPresented: $showGroundingPopover) {
                            SmartGroundingDetail(text: groundingText)
                                .frame(width: 360, height: 400)
                                .presentationCompactAdaptation(.popover)
                        }
                        #if os(iOS)
                        .sheet(isPresented: $showGroundingSheet) {
                            ScrollView(.vertical){
                                HStack{
                                    Text("Smart Grounding")
                                        .font(.title)
                                        .offset(x: 4, y: 4)
                                    Spacer()
                                }
                                .padding(4)
                                SmartGroundingDetail(text: groundingText)
                                    .padding(4)
                            }
                            .presentationDetents([.medium, .large])
                        }
                        #endif
                    }

                    if horizontalSizeClass == .compact{
                        Button {
                            showInfoPopOver.toggle()
                        } label: {
                            Label("Show message info", systemImage: "info.circle")
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                                #if os(iOS)
                                .hoverEffect(.highlight)
                                #endif
                                .scaleEffect(0.8)
                                .rotationEffect(showInfoPopOver ? Angle(degrees: 0) : Angle(degrees: -360))
                        }
                        .popover(isPresented: $showInfoPopOver) {
                            
                            VStack(alignment: .leading) {
                                Text(formatMessageTimestamp(message.timeStamp))
                                Text(message.timeStamp.formatted())
                                    .font(.caption)
                                    .opacity(0.7)
                                Divider()
                                Text(modelDisplayName)
                            }
                            .padding()
                            .presentationCompactAdaptation(.popover)
                        }
                        .buttonStyle(.plain)
                        .labelStyle(.iconOnly)
                    }
                    else{
                        if (isToolbarExpanded){
                            Divider()
                                .frame(height:12)
                                .opacity(0.7)
                                .padding(.horizontal, 4)
                                .transition(.offset(x: -10).combined(with: .opacity).combined(with: .scale(0.7)))
                            Text(formatMessageTimestamp(message.timeStamp))
                                .help(message.timeStamp.formatted())
                                .opacity(0.7)
                                .padding(.horizontal, 4)
                                .transition(.offset(x: -20).combined(with: .opacity).combined(with: .scale(0.7)))
                            Divider()
                                .frame(height:12)
                                .opacity(0.7)
                                .padding(.horizontal, 4)
                                .transition(.offset(x: -60).combined(with: .opacity).combined(with: .scale(0.7)))
                            Text(modelDisplayName)
                                .help(modelDisplayName)
                                .opacity(0.7)
                                .padding(.horizontal, 4)
                                .transition(.offset(x: -70).combined(with: .opacity).combined(with: .scale(0.7)))
                        }
                        
                        Button {
                            withAnimation(.bouncy(duration: 0.35, extraBounce: 0.05)) {
                                isToolbarExpanded.toggle()
                            }
                        } label: {
                            Label("Expand/Collapse toolbar", systemImage: "chevron.forward")
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                                #if os(iOS)
                                .hoverEffect(.highlight)
                                #endif
                                .scaleEffect(0.8)
                                .rotationEffect(isToolbarExpanded ? Angle(degrees: -180) : Angle(degrees: 0))
                        }
                        .buttonStyle(.plain)
                        .labelStyle(.iconOnly)
                        
                    }
                    Spacer()
                }
            }
            .padding(.leading, 10)
            .opacity(0.4)
            .padding(.top, -5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalSizeClass == .compact ? 0 : 8)
        .onAppear(){
            if toolbarExpansionPreference {isToolbarExpanded = true}
        }
    }
    
    func formatMessageTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private extension String {
    /// A line that is only a list marker ("5.", "3)", "-") parses as an empty list item,
    /// which Foundation's Markdown parser drops entirely, so short answers like "5." render
    /// as nothing. Escape the marker so it stays literal text.
    func escapingEmptyListMarkers() -> String {
        guard contains(where: { ".)-*+".contains($0) }) else { return self }
        var lines = components(separatedBy: "\n")
        var inCodeFence = false
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inCodeFence.toggle()
                continue
            }
            // Empty list items can't interrupt a paragraph, so only lines after a blank line matter
            let previousIsBlank = i == 0 || lines[i - 1].trimmingCharacters(in: .whitespaces).isEmpty
            guard !inCodeFence, previousIsBlank, let marker = trimmed.last else { continue }
            let body = trimmed.dropLast()
            let isOrdered = (marker == "." || marker == ")") && !body.isEmpty && body.count <= 9 && body.allSatisfy(\.isASCII) && body.allSatisfy(\.isNumber)
            let isBullet = body.isEmpty && "-*+".contains(marker)
            if isOrdered || isBullet {
                lines[i] = String(body) + "\\" + String(marker)
            }
        }
        return lines.joined(separator: "\n")
    }
}

private extension String {
    /// Replaces em-dashes with en-dashes. Between words the dash is spaced ("no—way" → "no – way"),
    /// at a cut-off it stays closed up ("*Oh, fuck—*…" → "*Oh, fuck–*…"). No space is ever put on
    /// the inner side of an emphasis delimiter, since that would stop it from opening/closing.
    /// Code blocks, code spans, link destinations and autolinks are left untouched.
    func spacingEmDashes() -> String {
        // Literal search, a Character-wise contains() walks grapheme clusters and is far slower
        guard range(of: "—", options: .literal) != nil else { return self }
        var fence: (marker: Character, length: Int)? = nil
        let lines = split(separator: "\n", omittingEmptySubsequences: false)
        return lines.indices.map { index -> String in
            let line = lines[index]
            let trimmed = line.drop(while: { $0 == " " })
            if let marker = trimmed.first, marker == "`" || marker == "~" {
                let length = trimmed.prefix(while: { $0 == marker }).count
                let rest = trimmed.dropFirst(length)
                if let open = fence {
                    if marker == open.marker, length >= open.length, rest.allSatisfy(\.isWhitespace) {
                        fence = nil
                    }
                    return String(line)
                }
                // A backtick fence's info string can't contain backticks, so "```a```" is a code span
                if length >= 3, !(marker == "`" && rest.contains("`")) {
                    fence = (marker, length)
                    return String(line)
                }
            }
            guard fence == nil, line.contains("—") else { return String(line) }
            return Self.spacingEmDashes(inLine: Array(line), isLastLine: index == lines.count - 1)
        }
        .joined(separator: "\n")
    }

    private static let openers: Set<Character> = ["(", "[", "{", "“", "‘", "«"]
    /// Emphasis delimiters plus straight quotes, which open or close depending on their neighbours
    private static let flanking: Set<Character> = ["*", "_", "~", "\"", "'"]

    /// CommonMark treats Unicode punctuation and symbols alike when deciding if a delimiter can open or close
    private static func isPunctuation(_ c: Character) -> Bool {
        c.isPunctuation || c.isSymbol
    }

    private static func spacingEmDashes(inLine chars: [Character], isLastLine: Bool) -> String {
        var out = ""
        out.reserveCapacity(chars.count + 8)
        var i = 0
        while i < chars.count {
            switch chars[i] {
            case "\\":
                let end = Swift.min(i + 2, chars.count)
                out.append(contentsOf: chars[i..<end])
                i = end
            case "`":
                let length = runLength(of: "`", in: chars, from: i)
                let end = closingBackticks(length: length, in: chars, from: i + length).map { $0 + length } ?? i + length
                out.append(contentsOf: chars[i..<end])
                i = end
            case "(" where i > 0 && chars[i - 1] == "]":
                let end = (matchingParen(in: chars, from: i) ?? i) + 1
                out.append(contentsOf: chars[i..<end])
                i = end
            case "<":
                let end = (autolinkEnd(in: chars, from: i) ?? i) + 1
                out.append(contentsOf: chars[i..<end])
                i = end
            case "—":
                let end = i + runLength(of: "—", in: chars, from: i)
                let continues = sentenceContinues(after: end, in: chars, isLastLine: isLastLine)
                if continues && wantsSpace(before: i, in: chars) { out.append(" ") }
                out.append("–")
                if continues && wantsSpace(after: end, in: chars) { out.append(" ") }
                i = end
            default:
                out.append(chars[i])
                i += 1
            }
        }
        return out
    }

    /// Whether a word follows the dash, making it a pause rather than a cut-off ("What the—").
    /// The end of the last line counts as continuing: while streaming, the next token usually
    /// finishes the sentence, and a closing "*" or quote arriving later still flips it to a cut-off.
    private static func sentenceContinues(after index: Int, in chars: [Character], isLastLine: Bool) -> Bool {
        var k = index
        while k < chars.count && chars[k].isWhitespace { k += 1 }
        guard k < chars.count else { return isLastLine && index == chars.count }
        let c = chars[k]
        if flanking.contains(c) {
            // Closing if followed by whitespace, punctuation or the line end ("fuck—*…")
            let after = k + runLength(of: c, in: chars, from: k)
            return after < chars.count && !chars[after].isWhitespace && !isPunctuation(chars[after])
        }
        return openers.contains(c) || !isPunctuation(c)
    }

    private static func wantsSpace(before index: Int, in chars: [Character]) -> Bool {
        guard index > 0 else { return false }
        let c = chars[index - 1]
        if c.isWhitespace || openers.contains(c) { return false }
        if flanking.contains(c) {
            // A run preceded by whitespace/punctuation opens against the dash ("*—oh*"), so no space;
            // otherwise it closes the previous word ("*oh*—yes") and a space after it is safe
            var k = index - 1
            while k >= 0 && chars[k] == c { k -= 1 }
            return k >= 0 && !chars[k].isWhitespace && !isPunctuation(chars[k])
        }
        return true
    }

    private static func wantsSpace(after index: Int, in chars: [Character]) -> Bool {
        guard index < chars.count else { return false }
        let c = chars[index]
        if c.isWhitespace { return false }
        if flanking.contains(c) {
            // Only a run that opens onto a word ("yes—*oh*") may be pushed away from the dash
            let after = index + runLength(of: c, in: chars, from: index)
            return after < chars.count && !chars[after].isWhitespace && !isPunctuation(chars[after])
        }
        return openers.contains(c) || !isPunctuation(c)
    }

    private static func runLength(of c: Character, in chars: [Character], from start: Int) -> Int {
        var end = start
        while end < chars.count && chars[end] == c { end += 1 }
        return end - start
    }

    /// Start of the next backtick run of exactly `length`, i.e. the end of a code span
    private static func closingBackticks(length: Int, in chars: [Character], from start: Int) -> Int? {
        var i = start
        while i < chars.count {
            guard chars[i] == "`" else { i += 1; continue }
            let run = runLength(of: "`", in: chars, from: i)
            if run == length { return i }
            i += run
        }
        return nil
    }

    /// Closing paren of a link destination "](…)", allowing nested parens
    private static func matchingParen(in chars: [Character], from start: Int) -> Int? {
        var depth = 0
        var i = start
        while i < chars.count {
            switch chars[i] {
            case "\\": i += 1
            case "(": depth += 1
            case ")":
                depth -= 1
                if depth == 0 { return i }
            default: break
            }
            i += 1
        }
        return nil
    }

    /// Closing ">" of an autolink like "<https://…>"
    private static func autolinkEnd(in chars: [Character], from start: Int) -> Int? {
        var i = start + 1
        var sawColon = false
        while i < chars.count {
            let c = chars[i]
            if c == ">" { return sawColon ? i : nil }
            if c.isWhitespace || c == "<" { return nil }
            if c == ":" { sawColon = true }
            i += 1
        }
        return nil
    }
}

private struct SmartGroundingDetail: View {
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt")
                        .foregroundStyle(.secondary)
                    Text("Smart Grounding for this turn:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                StructuredText(markdown: text)
                    .textual.textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

#Preview {
    //MessageModel(messageText: "User message")
}
