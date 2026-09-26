// Throwaway Journal prototype for "Journal: list, detail, editor and gate" (#78).
// Sample values; no data writes. Canvas picks: toolbar filter menu, compact rows,
// read-then-Edit detail, header-chip editor. The accepted decision is rewritten into
// production views, never merged from here.

import SwiftUI

// MARK: - Sample model

private enum ProtoKind: String, CaseIterable, Identifiable {
    case answer, note, retro, weekly, focus
    var id: String { rawValue }
    var label: String {
        switch self {
        case .answer: L("Answer", "Antwort")
        case .note: L("Note", "Notiz")
        case .retro: L("Retro", "Rückblick")
        case .weekly: L("Weekly review", "Wochenrückblick")
        case .focus: L("Focus note", "Fokusnotiz")
        }
    }
    var plural: String {
        switch self {
        case .answer: L("Answers", "Antworten")
        case .note: L("Notes", "Notizen")
        case .retro: L("Retros", "Rückblicke")
        case .weekly: L("Weekly reviews", "Wochenrückblicke")
        case .focus: L("Focus notes", "Fokusnotizen")
        }
    }
    var symbol: String {
        switch self {
        case .answer: "questionmark.bubble"
        case .note: "note.text"
        case .retro: "moon.stars"
        case .weekly: "calendar.badge.checkmark"
        case .focus: "timer"
        }
    }
}

private enum ProtoTheme: String, CaseIterable, Identifiable {
    case work, people, health, money, learning, making, home, rest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .work: L("Work", "Arbeit")
        case .people: L("People", "Menschen")
        case .health: L("Health", "Gesundheit")
        case .money: L("Money", "Geld")
        case .learning: L("Learning", "Lernen")
        case .making: L("Making", "Schaffen")
        case .home: L("Home", "Zuhause")
        case .rest: L("Rest", "Ruhe")
        }
    }
}

private enum ProtoDate: String, CaseIterable, Identifiable {
    case any, today, week, month
    var id: String { rawValue }
    var label: String {
        switch self {
        case .any: L("Any time", "Jederzeit")
        case .today: L("Today", "Heute")
        case .week: L("Last 7 days", "Letzte 7 Tage")
        case .month: L("Last 30 days", "Letzte 30 Tage")
        }
    }
    var maxAge: Int? {
        switch self {
        case .any: nil
        case .today: 0
        case .week: 6
        case .month: 29
        }
    }
}

private struct ProtoEntry: Identifiable, Hashable {
    let id: String
    let kind: ProtoKind
    let daysAgo: Int
    let time: String
    var edited: String? = nil
    var prompt: String? = nil
    var text: String = ""
    var fields: [String] = []
    var intention: String? = nil
    var mood: Mood? = nil
    var theme: ProtoTheme? = nil
    var theme2: ProtoTheme? = nil
    var otherVersionID: String? = nil

    var words: String { kind == .retro ? (fields.first { !$0.isEmpty } ?? "") : text }

    var title: String {
        if kind == .weekly { return prompt ?? "" }
        return Self.firstSentence(words)
    }
    var rest: String {
        if kind == .weekly { return text }
        let first = Self.firstSentence(words)
        let remainder = words.dropFirst(first.count).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return remainder.isEmpty ? (kind == .retro ? fields.dropFirst().first ?? "" : "") : remainder
    }

    static func firstSentence(_ s: String) -> String {
        let end = s.firstIndex { ".;!?".contains($0) } ?? s.endIndex
        return String(s[..<end])
    }
}

private let retroPrompts = [L("What went well?", "Was lief gut?"),
                            L("What can improve?", "Was geht besser?"),
                            L("Ideas & tomorrow", "Ideen & morgen")]

private let sample: [ProtoEntry] = [
    ProtoEntry(id: "a1", kind: .answer, daysAgo: 0, time: "08:14", edited: "21:02",
               prompt: "What would you do today if no one was watching?",
               text: "Finish the chapter I keep circling. Nobody is waiting for it, which is exactly why it keeps slipping. Two hours before lunch, phone in the other room.",
               mood: .steady, theme: .making, theme2: .work, otherVersionID: "a1b"),
    ProtoEntry(id: "n1", kind: .note, daysAgo: 0, time: "12:40",
               text: "Lunch with Maya. She said the thing about \"owning the calendar\" again. I think she means saying no before the meeting exists.",
               theme: .people),
    ProtoEntry(id: "r1", kind: .retro, daysAgo: 1, time: "21:30",
               fields: ["Shipped the draft before dinner.", "Started late; the morning went to email.", "Block 9 to 11 before opening anything."],
               intention: "No inbox before 11.", mood: .good, theme: .work),
    ProtoEntry(id: "a2", kind: .answer, daysAgo: 1, time: "07:52",
               prompt: "What are you avoiding that would take ten minutes?",
               text: "Calling the bank about the card. Ten minutes, maybe fifteen with hold music.",
               mood: .flat, theme: .money),
    ProtoEntry(id: "f1", kind: .focus, daysAgo: 2, time: "14:30", prompt: "Write chapter 3",
               text: "Got the opening scene down; the middle still drags.", theme: .making),
    ProtoEntry(id: "w1", kind: .weekly, daysAgo: 6, time: "19:05", prompt: "Week of 14 September",
               text: "Five of seven days. The two I missed were both travel days, so next time plan the practice before the trip, not during.",
               intention: "Pack the practice."),
]

/// The older record from an offline conflict; reachable only from the primary's detail.
private let otherVersion = ProtoEntry(id: "a1b", kind: .answer, daysAgo: 0, time: "08:09",
    prompt: "What would you do today if no one was watching?",
    text: "Probably nothing different, which is the honest answer and also the problem.", mood: .flat)

private func L(_ en: String, _ de: String) -> String {
    Locale.current.language.languageCode?.identifier == "de" ? de : en
}

private func dayTitle(_ daysAgo: Int) -> String {
    switch daysAgo {
    case 0: return L("Today", "Heute")
    case 1: return L("Yesterday", "Gestern")
    default:
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

private struct ProtoColors {
    let scheme: ColorScheme
    var accent: Color {
        scheme == .dark ? Color(red: 1, green: 212 / 255, blue: 51 / 255) : Color(red: 242 / 255, green: 196 / 255, blue: 28 / 255)
    }
    var accentInk: Color {
        scheme == .dark ? accent : Color(red: 110 / 255, green: 92 / 255, blue: 5 / 255)
    }
}

// MARK: - List

struct JournalPrototypeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var entries = sample
    @State private var search = ""
    @State private var kind: ProtoKind?
    @State private var mood: Mood?
    @State private var theme: ProtoTheme?
    @State private var date = ProtoDate.any
    @State private var locked = false
    @State private var empty = false
    @State private var composing: ProtoEntry?
    @State private var pendingDelete: ProtoEntry?

    private var colors: ProtoColors { ProtoColors(scheme: colorScheme) }
    private var filtering: Bool { kind != nil || mood != nil || theme != nil || date != .any }

    private var visible: [ProtoEntry] {
        guard !empty else { return [] }
        return entries.filter { e in
            (kind == nil || e.kind == kind)
                && (mood == nil || e.mood == mood)
                && (theme == nil || e.theme == theme || e.theme2 == theme)
                && (date.maxAge.map { e.daysAgo <= $0 } ?? true)
                && (search.isEmpty || [e.prompt ?? "", e.text, e.fields.joined(separator: " ")].joined(separator: " ")
                        .localizedCaseInsensitiveContains(search))
        }
    }

    private var days: [(Int, [ProtoEntry])] {
        Dictionary(grouping: visible, by: \.daysAgo).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private var filterSummary: String {
        [kind?.plural, mood?.label, theme?.label, date == .any ? nil : date.label].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            Group {
                if locked {
                    ContentUnavailableView {
                        Label(L("Your journal is locked.", "Dein Journal ist gesperrt."), systemImage: "lock")
                    } actions: {
                        Button(L("Unlock", "Entsperren")) { locked = false }
                            .buttonStyle(.bordered)
                    }
                } else if empty && !filtering && search.isEmpty {
                    ContentUnavailableView {
                        Label(L("Nothing written yet.", "Noch nichts geschrieben."), systemImage: "book.closed")
                    } actions: {
                        Button(L("Write a note", "Notiz schreiben")) { composing = newNote() }
                            .buttonStyle(.bordered)
                    }
                } else {
                    list
                }
            }
            .navigationTitle(L("Journal", "Journal"))
            .toolbar { toolbar }
            .safeAreaBar(edge: .bottom, alignment: .trailing) {
                Button(L("New note", "Neue Notiz"), systemImage: "plus") { composing = newNote() }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .tint(colors.accent)
                    .foregroundStyle(.black)
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
            }
            .sheet(item: $composing) { entry in
                JournalPrototypeEditor(entry: entry, isNew: entry.id.hasPrefix("new"))
            }
            .confirmationDialog(L("Delete this entry?", "Diesen Eintrag löschen?"), isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button(L("Delete entry", "Eintrag löschen"), role: .destructive) {
                    entries.removeAll { $0.id == pendingDelete?.id }
                }
            } message: {
                Text(L("It is removed from this device and your iCloud.", "Er wird von diesem Gerät und aus deiner iCloud entfernt."))
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        List {
            if filtering {
                Section {
                    HStack {
                        Text(filterSummary).foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Button(L("Clear", "Löschen")) { clearFilters() }
                            .foregroundStyle(colors.accentInk)
                    }
                    .font(.subheadline)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                }
            } else if search.isEmpty {
                Section {
                    NavigationLink {
                        Text("Drafts (prototype stub)")
                    } label: {
                        Label(L("Unsaved drafts (1)", "Ungesicherte Entwürfe (1)"), systemImage: "doc.badge.clock")
                    }
                }
            }
            if visible.isEmpty && filtering && search.isEmpty {
                Section {
                    Text(L("No entries match.", "Keine Einträge passen.")).foregroundStyle(.secondary)
                    Button(L("Clear filters", "Filter löschen")) { clearFilters() }
                        .foregroundStyle(colors.accentInk)
                }
            }
            ForEach(days, id: \.0) { day, items in
                Section(dayTitle(day)) {
                    ForEach(items) { entry in
                        NavigationLink(value: entry) { JournalPrototypeRow(entry: entry) }
                            .swipeActions(edge: .trailing) {
                                Button(L("Delete", "Löschen"), systemImage: "trash") { pendingDelete = entry }
                                    .tint(.red)
                            }
                    }
                }
            }
        }
        .navigationDestination(for: ProtoEntry.self) { JournalPrototypeDetail(entry: $0) }
        .overlay {
            if visible.isEmpty && !search.isEmpty { ContentUnavailableView.search(text: search) }
        }
        .searchable(text: $search, prompt: Text(L("Search", "Suchen")))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // Prototype only: flip states that are hard to reach with sample data.
            Menu("Prototype", systemImage: "hammer") {
                Toggle("Locked", isOn: $locked)
                Toggle("Empty journal", isOn: $empty)
            }
        }
        if !locked && !(empty && !filtering) {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(L("Kind", "Art"), selection: $kind) {
                        Text(L("All", "Alle")).tag(ProtoKind?.none)
                        ForEach(ProtoKind.allCases) { Label($0.plural, systemImage: $0.symbol).tag(Optional($0)) }
                    }
                    .pickerStyle(.inline)
                    Picker(L("Mood", "Stimmung"), selection: $mood) {
                        Text(L("Any mood", "Jede Stimmung")).tag(Mood?.none)
                        ForEach(Mood.allCases) { Label($0.label, systemImage: $0.systemImage).tag(Optional($0)) }
                    }
                    .pickerStyle(.menu)
                    Picker(L("Theme", "Thema"), selection: $theme) {
                        Text(L("Any theme", "Jedes Thema")).tag(ProtoTheme?.none)
                        ForEach(ProtoTheme.allCases) { Text($0.label).tag(Optional($0)) }
                    }
                    .pickerStyle(.menu)
                    Picker(L("Date", "Datum"), selection: $date) {
                        ForEach(ProtoDate.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                } label: {
                    Label(L("Filter", "Filter"), systemImage: filtering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                }
                .tint(filtering ? colors.accentInk : nil)
            }
        }
    }

    private func clearFilters() { kind = nil; mood = nil; theme = nil; date = .any }
    private func newNote() -> ProtoEntry { ProtoEntry(id: "new-\(UUID().uuidString)", kind: .note, daysAgo: 0, time: Date.now.formatted(date: .omitted, time: .shortened)) }
}

// MARK: - Compact row

private struct JournalPrototypeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: ProtoEntry

    var body: some View {
        let ax = dynamicTypeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            Image(systemName: entry.kind.symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, minHeight: 28)
                .background(.quaternary, in: .rect(cornerRadius: 8))
                .accessibilityLabel(entry.kind.label)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(ax ? 3 : 1)
                Group {
                    if ax {
                        Text(entry.time).foregroundStyle(.primary)
                        Text(entry.rest).lineLimit(2)
                    } else {
                        (Text(entry.time).foregroundStyle(.primary) + Text("  ") + Text(entry.rest))
                            .lineLimit(1)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                let tags = [entry.mood.map { $0.label }, entry.theme?.label].compactMap { $0 }
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        if let mood = entry.mood { Image(systemName: mood.systemImage) }
                        Text(tags.joined(separator: " · "))
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Read detail

private struct JournalPrototypeDetail: View {
    @Environment(\.dismiss) private var dismiss
    let entry: ProtoEntry
    @State private var editing: ProtoEntry?
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text(dayDate(entry.daysAgo)).font(.footnote).foregroundStyle(.secondary)
                    if entry.kind == .retro {
                        ForEach(Array(zip(retroPrompts, entry.fields)), id: \.0) { prompt, answer in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(prompt).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                Text(answer).font(.body)
                            }
                        }
                        if let intention = entry.intention {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L("Intention for tomorrow", "Vorsatz für morgen")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                Text(intention).font(.body)
                            }
                        }
                    } else {
                        if let prompt = entry.prompt {
                            Text(prompt)
                                .font(.title3).fontDesign(.serif)
                                .foregroundStyle(entry.kind == .focus ? .secondary : .primary)
                        }
                        Text(entry.text).font(.body).textSelection(.enabled)
                        if entry.kind == .weekly, let next = entry.intention {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L("Next week", "Nächste Woche")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                Text(next).font(.body)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Written", "Geschrieben") + " \(entry.time)" + (entry.edited.map { " · " + L("Edited", "Bearbeitet") + " \($0)" } ?? ""))
                        let tags = [entry.mood?.label, entry.theme?.label, entry.theme2?.label].compactMap { $0 }
                        if !tags.isEmpty { Text(tags.joined(separator: " · ")) }
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            }
            if entry.otherVersionID != nil {
                Section {
                    NavigationLink(L("Another version from this day", "Weitere Version von diesem Tag")) {
                        JournalPrototypeDetail(entry: otherVersion)
                    }
                }
            }
            Section {
                Button(L("Delete entry", "Eintrag löschen"), role: .destructive) { confirmingDelete = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(entry.kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("Edit", "Bearbeiten")) { editing = entry }
            }
        }
        .sheet(item: $editing) { JournalPrototypeEditor(entry: $0, isNew: false) }
        .confirmationDialog(L("Delete this entry?", "Diesen Eintrag löschen?"), isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(L("Delete entry", "Eintrag löschen"), role: .destructive) { dismiss() }
        }
    }
}

private func dayDate(_ daysAgo: Int) -> String {
    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
    return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
}

// MARK: - Editor (header chips)

private struct JournalPrototypeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft: ProtoEntry
    @State private var themeTouched = false
    @State private var suggested = false
    @State private var suggestTask: Task<Void, Never>?
    @FocusState private var focused: Bool
    let isNew: Bool

    init(entry: ProtoEntry, isNew: Bool) {
        _draft = State(initialValue: entry)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(dayDate(draft.daysAgo) + (isNew ? " · \(draft.time)" : ""))
                        .font(.footnote).foregroundStyle(.secondary)
                    if let prompt = draft.prompt, draft.kind != .retro {
                        Text(prompt)
                            .font(.title3).fontDesign(.serif)
                            .foregroundStyle(draft.kind == .focus ? .secondary : .primary)
                    }
                    if draft.kind != .weekly { chips }
                    if draft.kind == .retro {
                        ForEach(retroPrompts.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(retroPrompts[i]).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                TextField("", text: Binding(get: { draft.fields[safe: i] ?? "" }, set: { setField(i, $0) }), axis: .vertical)
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L("Intention for tomorrow", "Vorsatz für morgen")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                            TextField("", text: Binding(get: { draft.intention ?? "" }, set: { draft.intention = $0 }), axis: .vertical)
                        }
                    } else {
                        TextField(L("Start writing", "Schreib los"), text: $draft.text, axis: .vertical)
                            .font(.body)
                            .focused($focused)
                            .lineLimit(6...)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? L("New note", "Neue Notiz") : draft.kind.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) { dismiss() } }
            }
            .onAppear { if isNew { focused = true } }
            .onChange(of: draft.text) { _, text in schedulePrefill(text) }
        }
        .presentationDetents([.large])
    }

    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { moodChip; themeChip }
            VStack(alignment: .leading, spacing: 8) { moodChip; themeChip }
        }
    }

    private var moodChip: some View {
        Menu {
            Picker(L("Mood", "Stimmung"), selection: $draft.mood) {
                Text(L("No mood", "Keine Stimmung")).tag(Mood?.none)
                ForEach(Mood.allCases) { Label($0.label, systemImage: $0.systemImage).tag(Optional($0)) }
            }
        } label: {
            Label(draft.mood?.label ?? L("Mood", "Stimmung"), systemImage: draft.mood?.systemImage ?? "face.smiling")
                .foregroundStyle(draft.mood == nil ? .secondary : .primary)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.secondary)
    }

    private var themeChip: some View {
        Menu {
            Section(L("Up to two", "Bis zu zwei")) {
                ForEach(ProtoTheme.allCases) { theme in
                    Button { toggle(theme) } label: {
                        if draft.theme == theme || draft.theme2 == theme {
                            Label(theme.label, systemImage: "checkmark")
                        } else {
                            Text(theme.label)
                        }
                    }
                }
            }
        } label: {
            let names = [draft.theme?.label, draft.theme2?.label].compactMap { $0 }
            HStack(spacing: 5) {
                if suggested { Image(systemName: "sparkle") }
                Text(names.isEmpty ? L("Theme", "Thema") : names.joined(separator: " · "))
                if suggested { Text(L("Suggested", "Vorgeschlagen")).foregroundStyle(.secondary) }
            }
            .foregroundStyle(names.isEmpty ? .secondary : .primary)
        }
        .menuActionDismissBehavior(.disabled)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.secondary)
    }

    private func toggle(_ theme: ProtoTheme) {
        themeTouched = true
        suggested = false
        suggestTask?.cancel()
        if draft.theme == theme { draft.theme = draft.theme2; draft.theme2 = nil }
        else if draft.theme2 == theme { draft.theme2 = nil }
        else if draft.theme == nil { draft.theme = theme }
        else { draft.theme2 = theme }
    }

    /// Stand-in for the Foundation Models pre-fill: 1.5 s after typing pauses, past ~8 words.
    private func schedulePrefill(_ text: String) {
        suggestTask?.cancel()
        guard !themeTouched, text.split(separator: " ").count >= 8 else { return }
        suggestTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, !themeTouched else { return }
            draft.theme = text.localizedCaseInsensitiveContains("idea") ? .making : .work
            suggested = true
        }
    }

    private func setField(_ i: Int, _ value: String) {
        while draft.fields.count <= i { draft.fields.append("") }
        draft.fields[i] = value
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

#Preview {
    JournalPrototypeView()
}
