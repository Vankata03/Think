//
//  JournalView.swift
//  Think
//

import SwiftUI

/// Journal history. Reads go through bounded repository pages, never a live
/// query, and nothing private is fetched while the lock is engaged. The
/// blank New note path stays available while locked because capturing a
/// fresh thought grants no read access.
struct JournalView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case all, notes, questions, focus, retros

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: String(localized: "All")
            case .notes: String(localized: "Notes")
            case .questions: String(localized: "Questions")
            case .focus: String(localized: "Focus")
            case .retros: String(localized: "Retros")
            }
        }

        var entryKind: String? {
            switch self {
            case .all, .retros: nil
            case .notes: JournalEntry.kindNote
            case .questions: JournalEntry.kindQuestion
            case .focus: JournalEntry.kindFocus
            }
        }

        var includesEntries: Bool { self != .retros }
        var includesRetros: Bool { self == .all || self == .retros }

        var emptyMessage: String {
            switch self {
            case .all:
                String(localized: "Nothing written yet. Tap + to start a note.")
            case .notes:
                String(localized: "Write anything on your mind. Tap + to start.")
            case .questions:
                String(localized: "Your answers to the daily question will appear here.")
            case .focus:
                String(localized: "Start a focus session with an intention and your closing notes will appear here.")
            case .retros:
                String(localized: "Close each day with two honest minutes. Your evening retrospectives will appear here.")
            }
        }
    }

    private enum MoodSelection: Hashable, CaseIterable {
        case all, untagged
        case tagged(Mood)

        static var allCases: [MoodSelection] { [.all, .untagged] + Mood.allCases.map { .tagged($0) } }

        var label: String {
            switch self {
            case .all: String(localized: "Any mood")
            case .untagged: String(localized: "No mood")
            case .tagged(let mood): mood.label
            }
        }

        var filter: JournalRepository.MoodFilter {
            switch self {
            case .all: .all
            case .untagged: .untagged
            case .tagged(let mood): .tagged(mood)
            }
        }
    }

    private enum DateSelection: String, CaseIterable, Identifiable {
        case any, today, week, month

        var id: String { rawValue }

        var label: String {
            switch self {
            case .any: String(localized: "Any time")
            case .today: String(localized: "Today")
            case .week: String(localized: "Last 7 days")
            case .month: String(localized: "Last 30 days")
            }
        }

        func interval(now: Date = .now) -> DateInterval? {
            let today = CivilDay.today(now: now)
            switch self {
            case .any: return nil
            case .today: return today.interval
            case .week: return DateInterval(start: today.adding(days: -6).start, end: today.next.start)
            case .month: return DateInterval(start: today.adding(days: -29).start, end: today.next.start)
            }
        }
    }

    /// One row of the merged timeline. Retros and entries are separate
    /// tables, so the All view interleaves two bounded pages by date.
    private enum Row: Identifiable {
        case entry(JournalRepository.EntrySnapshot)
        case retro(JournalRepository.RetroSnapshot)

        var id: String {
            switch self {
            case .entry(let value): "entry-\(value.recordID?.uuidString ?? String(describing: value.persistentModelID))"
            case .retro(let value): "retro-\(value.recordID?.uuidString ?? String(describing: value.persistentModelID))"
            }
        }
        var date: Date {
            switch self {
            case .entry(let value): value.date
            case .retro(let value): value.date
            }
        }
    }

    private struct QueryKey: Hashable {
        var section: Section
        var search: String
        var mood: MoodSelection
        var date: DateSelection
        var revision: Int
        var locked: Bool
    }

    private static let pageSize = 50

    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var section = Section.all
    @State private var search = ""
    @State private var mood = MoodSelection.all
    @State private var dateSelection = DateSelection.any
    @State private var entries: [JournalRepository.EntrySnapshot] = []
    @State private var retros: [JournalRepository.RetroSnapshot] = []
    @State private var entryTotal = 0
    @State private var retroTotal = 0
    @State private var entriesHaveMore = false
    @State private var retrosHaveMore = false
    @State private var entryOffset = 0
    @State private var retroOffset = 0
    @State private var recoverableCount = 0
    /// Draft files on disk that could not be decoded. They stay untouched;
    /// the count is shown so a healthy draft is never hidden by a broken one.
    @State private var unreadableDraftCount = 0
    @State private var loadError: String?
    @State private var composingNote: JournalDraft?
    @State private var composingRetro = false
    @State private var authenticating = false

    private var queryKey: QueryKey {
        QueryKey(section: section, search: search, mood: mood, date: dateSelection,
                 revision: repository.revision, locked: lock.isLocked)
    }

    private var rows: [Row] {
        (entries.map(Row.entry) + retros.map(Row.retro)).sorted { $0.date > $1.date }
    }

    private var hasMore: Bool {
        (section.includesEntries && entriesHaveMore) || (section.includesRetros && retrosHaveMore)
    }

    private var totalCount: Int {
        (section.includesEntries ? entryTotal : 0) + (section.includesRetros ? retroTotal : 0)
    }

    private var isFiltering: Bool { !search.isEmpty || mood != .all || dateSelection != .any }

    var body: some View {
        Group {
            if lock.isLocked {
                JournalGate()
            } else {
                entryList
            }
        }
        .navigationTitle("Journal")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("JournalView")
        .toolbar {
            // No + under Focus: a focus note is written when a session
            // ends, never composed from here. Blank capture stays available
            // while locked; only reading is gated.
            if section != .focus {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if section == .retros {
                            composingRetro = true
                        } else {
                            composingNote = JournalDraft(kind: .note)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(section == .retros
                                        ? String(localized: "New retrospective")
                                        : String(localized: "New note"))
                    .accessibilityIdentifier("NewNote")
                }
            }
        }
        .sheet(item: $composingNote) { draft in
            JournalEditor(draft: draft)
        }
        .sheet(isPresented: $composingRetro) {
            RetroSheet()
        }
        .task {
            // Ask straight away: the gate's Unlock button is the retry
            // path, not the first step.
            await unlock()
        }
        .task(id: queryKey) {
            guard !lock.isLocked else { clear(); return }
            // Debounce typing so each keystroke does not scan history.
            if !search.isEmpty {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
            reload()
        }
        .onChange(of: drafts.revision) { _, _ in refreshRecoverableCount() }
    }

    private var entryList: some View {
        List {
            SwiftUI.Section {
                sectionPicker
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                filterBar
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            if recoverableCount > 0 || unreadableDraftCount > 0 {
                SwiftUI.Section {
                    NavigationLink {
                        JournalRecoveryView()
                    } label: {
                        Label {
                            Text("Unsaved drafts (\(recoverableCount))")
                        } icon: {
                            Image(systemName: "doc.badge.clock")
                        }
                    }
                    .accessibilityIdentifier("RecoverDrafts")
                } footer: {
                    if unreadableDraftCount > 0 {
                        Text("\(unreadableDraftCount) draft file(s) could not be read. They were left untouched.")
                            .accessibilityIdentifier("UnreadableDraftsWarning")
                    }
                }
            }

            SwiftUI.Section {
                JournalStorageWarning()
                if let loadError {
                    Text(loadError).foregroundStyle(.red).accessibilityIdentifier("JournalLoadError")
                }
                if rows.isEmpty && loadError == nil {
                    Text(isFiltering ? String(localized: "No entries match these filters.") : section.emptyMessage)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("JournalEmpty")
                } else {
                    ForEach(rows) { row in
                        rowView(row)
                    }
                    if hasMore {
                        Button {
                            loadMore()
                        } label: {
                            Label("Load more", systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("JournalLoadMore")
                    }
                }
            } footer: {
                if totalCount > 0 {
                    Text("\(rows.count) of \(totalCount) shown")
                }
            }
        }
        .searchable(text: $search, prompt: Text("Search prompts and text"))
        .refreshable { reload() }
        .accessibilityIdentifier("JournalList")
    }

    @ViewBuilder
    private var sectionPicker: some View {
        let picker = Picker("Entries", selection: $section) {
            ForEach(Section.allCases) { section in
                Text(section.label).tag(section)
            }
        }
        .accessibilityIdentifier("JournalSectionPicker")
        // Five localized labels do not fit reliably in a segmented control.
        picker.pickerStyle(.menu)
    }

    /// Two compact menus; a layout that wraps rather than truncates at
    /// large text sizes.
    private var filterBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { filterMenus }
            VStack(alignment: .leading, spacing: 8) { filterMenus }
        }
    }

    @ViewBuilder
    private var filterMenus: some View {
        Menu {
            Picker("Mood", selection: $mood) {
                ForEach(MoodSelection.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            Label(mood.label, systemImage: mood == .all ? "face.smiling" : "face.smiling.inverse")
                .font(.footnote.weight(.medium))
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("JournalMoodFilter")

        Menu {
            Picker("Date", selection: $dateSelection) {
                ForEach(DateSelection.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            Label(dateSelection.label, systemImage: "calendar")
                .font(.footnote.weight(.medium))
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("JournalDateFilter")

        if isFiltering {
            Button("Clear") {
                search = ""; mood = .all; dateSelection = .any
            }
            .font(.footnote.weight(.medium))
            .buttonStyle(.bordered)
            .accessibilityIdentifier("JournalClearFilters")
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row {
        case .entry(let entry):
            if let id = entry.recordID {
                NavigationLink {
                    JournalEntryDetailView(recordID: id)
                } label: {
                    JournalEntryRow(entry: entry)
                }
            } else {
                JournalEntryRow(entry: entry)
            }
        case .retro(let retro):
            if let id = retro.recordID {
                NavigationLink {
                    JournalRetroDetailView(recordID: id)
                } label: {
                    JournalRetroRow(retro: retro)
                }
            } else {
                JournalRetroRow(retro: retro)
            }
        }
    }

    private func unlock() async {
        guard lock.isLocked, !authenticating else { return }
        authenticating = true
        _ = await lock.authenticate()
        authenticating = false
    }

    private func clear() {
        entries = []; retros = []
        entryTotal = 0; retroTotal = 0
        entriesHaveMore = false; retrosHaveMore = false
        entryOffset = 0; retroOffset = 0
        recoverableCount = 0
        unreadableDraftCount = 0
    }

    private func reload() {
        clear()
        loadError = nil
        loadPage(reset: true)
        refreshRecoverableCount()
    }

    private func loadMore() {
        loadPage(reset: false)
    }

    private func loadPage(reset: Bool) {
        guard !lock.isLocked else { return }
        let range = dateSelection.interval()
        do {
            if section.includesEntries && (reset || entriesHaveMore) {
                let query = JournalRepository.EntryQuery(search: search, kind: section.entryKind, mood: mood.filter, dateRange: range)
                let page = try repository.entries(matching: query, page: .init(offset: entryOffset, limit: Self.pageSize))
                entries += page.records
                entryTotal = page.totalCount
                entriesHaveMore = page.hasMore
                entryOffset = page.nextOffset
            }
            if section.includesRetros && (reset || retrosHaveMore) {
                let query = JournalRepository.RetroQuery(search: search, mood: mood.filter, dateRange: range)
                let page = try repository.retros(matching: query, page: .init(offset: retroOffset, limit: Self.pageSize))
                retros += page.records
                retroTotal = page.totalCount
                retrosHaveMore = page.hasMore
                retroOffset = page.nextOffset
            }
        } catch {
            loadError = String(localized: "Could not load your journal. Pull to try again.")
        }
    }

    private func refreshRecoverableCount() {
        guard !lock.isLocked else { recoverableCount = 0; unreadableDraftCount = 0; return }
        do {
            let listing = try drafts.recoverableListing()
            recoverableCount = listing.drafts.count
            unreadableDraftCount = listing.unreadableCount
        } catch { recoverableCount = 0; unreadableDraftCount = 0 }
    }
}
