//
//  JournalView.swift
//  Think
//

import SwiftUI

/// The Journal tab's list (`design/journal.md` sections 2, 3, 7 and 9):
/// one section per civil day, search under the title and a filter menu in
/// the toolbar. Reads go through bounded repository pages, never a live
/// query, and nothing private is fetched or drawn while the lock is
/// engaged. New note stays available while locked because capturing a
/// fresh thought grants no read access.
struct JournalView: View {
    private struct QueryKey: Hashable {
        var filter: JournalFilter
        var search: String
        var revision: Int
        var locked: Bool
    }

    private static let pageSize = 50
    private static let loadError = String(localized: "Could not load your journal.")

    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ThinkSpacing.Scaled(ThinkSpacing.xs) private var tightGap
    @ThinkSpacing.Scaled(ThinkSpacing.s) private var gap

    @State private var filter = JournalFilter()
    @State private var search = ""
    @State private var timeline = JournalTimeline(entries: nil, retros: nil)
    /// Other versions of a day (`design/journal.md` section 6), read once
    /// per repository revision.
    @State private var versions: (revision: Int, ids: Set<UUID>)?
    @State private var loaded = false
    @State private var journalEmpty = false
    @State private var hasFocusNotes = false
    @State private var loadFailed = false
    /// A failed Load more or delete. Shown as a row; what did load stays.
    @State private var actionError: String?
    @State private var recoverableCount = 0
    /// Draft files on disk that could not be decoded. They stay untouched;
    /// the count is shown so a healthy draft is never hidden by a broken one.
    @State private var unreadableDraftCount = 0
    @State private var composingNote: JournalDraft?
    @State private var pendingDelete: JournalTimeline.Record?
    @State private var authenticating = false

    private var queryKey: QueryKey {
        QueryKey(filter: filter, search: search, revision: repository.revision, locked: lock.isLocked)
    }

    private var isSearching: Bool { !search.isEmpty }
    private var hasStatusRows: Bool { repository.storageWarning != nil || actionError != nil || showsDrafts }
    private var showsDrafts: Bool {
        (recoverableCount > 0 || unreadableDraftCount > 0) && !filter.isActive && !isSearching
    }

    var body: some View {
        Group {
            if lock.isLocked {
                JournalGate()
            } else {
                list
            }
        }
        .navigationTitle("Journal")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("JournalView")
        .toolbar {
            if !lock.isLocked && loaded && !journalEmpty {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
        }
        .safeAreaBar(edge: .bottom, alignment: .trailing) { newNoteButton }
        .sheet(item: $composingNote) { draft in
            JournalEditor(draft: draft)
        }
        .confirmationDialog(deleteTitle, isPresented: deleteIsPresented, titleVisibility: .visible, presenting: pendingDelete) { record in
            Button("Delete entry", role: .destructive) { delete(record) }
                .accessibilityIdentifier("ConfirmDeleteEntry")
        } message: { _ in
            Text("It is removed from this device and your iCloud.")
        }
        .task {
            // Ask straight away: the gate's Unlock button is the retry
            // path, not the first step.
            await unlock()
        }
        .task(id: queryKey) {
            guard !lock.isLocked else { clear(); return }
            // Debounce typing so each keystroke does not scan history.
            if isSearching {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
            reload()
        }
        .onChange(of: lock.isLocked) { _, locked in
            if locked { search = "" }
        }
        .onChange(of: drafts.revision) { _, _ in refreshRecoverableCount() }
    }

    // MARK: List

    private var list: some View {
        List {
            if filter.isActive && !journalEmpty {
                Section { activeFilters }
            }
            statusRows
            if filter.isActive && !isSearching && loaded && timeline.isEmpty && !journalEmpty && !loadFailed {
                Section { filterNoMatch }
            }
            // Below the status rows rather than over them.
            if loaded && journalEmpty && hasStatusRows {
                Section { emptyState.listRowBackground(Color.clear) }
            }
            ForEach(timeline.days) { day in
                Section {
                    ForEach(day.records) { record in row(record) }
                } header: {
                    Text(JournalTimeline.title(for: day.day))
                }
            }
            if timeline.hasMore {
                Section {
                    Button("Load more") { loadMore() }
                        .thinkButton(.tertiary)
                        .accessibilityIdentifier("JournalLoadMore")
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("JournalList")
        .overlay { stateView }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search"))
        .refreshable { reload() }
    }

    /// The filter names joined by " · ", and Clear.
    private var activeFilters: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: tightGap))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: gap))
        return layout {
            Text(filter.summary)
                .foregroundStyle(ThinkColor.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Clear") { filter.clear() }
                .thinkButton(.tertiary)
                .accessibilityIdentifier("JournalClearFilters")
        }
        .font(.think(.secondary))
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("JournalActiveFilters")
    }

    /// Only the rows that apply, above the timeline and never instead of
    /// it. The storage warning shows whatever the filter, because it
    /// changes whether new writing is kept.
    @ViewBuilder
    private var statusRows: some View {
        if hasStatusRows {
            Section {
                JournalStorageWarning()
                if let actionError {
                    Label(actionError, systemImage: ThinkSymbol.unavailable)
                        .font(.think(.secondary))
                        .accessibilityIdentifier("JournalActionError")
                }
                if showsDrafts {
                    NavigationLink {
                        JournalRecoveryView()
                    } label: {
                        // At accessibility sizes the icon would break the
                        // title mid-word (`design/journal.md` section 13).
                        if dynamicTypeSize.isAccessibilitySize {
                            Text("Unsaved drafts (\(recoverableCount))")
                        } else {
                            // Row symbols stay monochrome (design-system section 2.2).
                            Label {
                                Text("Unsaved drafts (\(recoverableCount))")
                            } icon: {
                                Image(systemName: ThinkSymbol.drafts).foregroundStyle(ThinkColor.secondaryLabel)
                            }
                        }
                    }
                    .accessibilityIdentifier("RecoverDrafts")
                }
            } footer: {
                if showsDrafts && unreadableDraftCount > 0 {
                    Text("\(unreadableDraftCount) draft file(s) could not be read. They were left untouched.")
                        .accessibilityIdentifier("UnreadableDraftsWarning")
                }
            }
        }
    }

    private var filterNoMatch: some View {
        VStack(alignment: .leading, spacing: gap) {
            Text("No entries match.")
                .foregroundStyle(ThinkColor.secondaryLabel)
            Button("Clear filters") { filter.clear() }
                .thinkButton(.tertiary)
        }
        .font(.think(.body))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("JournalFilterNoMatch")
    }

    /// Whole-screen states (design-system section 8). The whole-journal
    /// Empty state shows whatever filter is on.
    @ViewBuilder
    private var stateView: some View {
        if loaded && journalEmpty {
            if !hasStatusRows { emptyState }
        } else if loadFailed {
            ContentUnavailableView {
                Label("Could not load your journal.", systemImage: ThinkSymbol.unavailable)
            } actions: {
                Button("Try again") { reload() }
                    .thinkButton(.secondary)
            }
            .accessibilityIdentifier("JournalLoadError")
        } else if loaded && isSearching && timeline.isEmpty {
            ContentUnavailableView.search(text: search)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing written yet.", systemImage: ThinkSymbol.journal)
        } actions: {
            Button("Write a note") { composeNote() }
                .thinkButton(.secondary)
        }
        .accessibilityIdentifier("JournalEmpty")
    }

    @ViewBuilder
    private func row(_ record: JournalTimeline.Record) -> some View {
        let isOtherVersion = record.recordID.map { versions?.ids.contains($0) ?? false } ?? false
        let content = switch record {
        case .entry(let entry): JournalRowContent(entry, isOtherVersion: isOtherVersion)
        case .retro(let retro): JournalRowContent(retro, isOtherVersion: isOtherVersion)
        }
        if let id = record.recordID {
            NavigationLink {
                switch record {
                case .entry: JournalEntryDetailView(recordID: id)
                case .retro: JournalRetroDetailView(recordID: id)
                }
            } label: {
                JournalRow(content: content)
            }
            // Tinted red without the destructive role, so the row stays
            // until the deletion is confirmed.
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", systemImage: ThinkSymbol.delete) { pendingDelete = record }
                    .tint(ThinkColor.destructive)
            }
            .accessibilityIdentifier("JournalRow.\(id.uuidString)")
        } else {
            JournalRow(content: content)
        }
    }

    // MARK: Chrome

    private var filterMenu: some View {
        Menu {
            Picker("Kind", selection: $filter.kind) {
                ForEach(JournalFilter.Kind.allCases.filter { $0 != .focusNotes || hasFocusNotes || filter.kind == .focusNotes }, id: \.self) { kind in
                    if let symbol = kind.symbol {
                        Label(kind.label, systemImage: symbol).tag(kind)
                    } else {
                        Text(kind.label).tag(kind)
                    }
                }
            }
            .pickerStyle(.inline)
            Picker("Mood", selection: $filter.mood) {
                ForEach(JournalFilter.MoodChoice.allCases, id: \.self) { choice in
                    if case .mood(let mood) = choice {
                        Label(mood.label, systemImage: mood.systemImage).tag(choice)
                    } else {
                        Text(choice.label).tag(choice)
                    }
                }
            }
            .pickerStyle(.menu)
            Picker("Theme", selection: $filter.theme) {
                Text("Any theme").tag(Theme?.none)
                ForEach(Theme.allCases) { theme in
                    Text(theme.label).tag(Theme?.some(theme))
                }
            }
            .pickerStyle(.menu)
            Picker("Date", selection: $filter.date) {
                ForEach(JournalFilter.DateRange.allCases, id: \.self) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.menu)
        } label: {
            Label("Filter", systemImage: filter.isActive ? ThinkSymbol.filterActive : ThinkSymbol.filter)
        }
        // Bar items stay monochrome (design-system section 2.2); the filled
        // symbol and the active filters line carry the state.
        .tint(ThinkColor.label)
        .accessibilityIdentifier("JournalFilterMenu")
    }

    private var newNoteButton: some View {
        Button("New note", systemImage: ThinkSymbol.add) { composeNote() }
            .labelStyle(.iconOnly)
            .font(.title2)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .thinkButton(.primary)
            .padding(.trailing, ThinkSpacing.l)
            .padding(.bottom, ThinkSpacing.s)
            .accessibilityIdentifier("NewNote")
    }

    // MARK: Delete

    private var deleteTitle: Text {
        if case .retro = pendingDelete { Text("Delete this retro?") } else { Text("Delete this entry?") }
    }

    private var deleteIsPresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    /// Removes the record, then any unsaved edit of it, with the detail's
    /// failure messages.
    private func delete(_ record: JournalTimeline.Record) {
        guard let id = record.recordID else { return }
        do {
            switch record {
            case .entry: try repository.deleteEntry(id: id)
            case .retro: try repository.deleteRetro(id: id)
            }
        } catch {
            actionError = String(localized: "Could not delete this entry. It is still here. Try again.")
            return
        }
        do {
            if let draft = try existingEditingDraft(for: id, in: drafts) {
                try drafts.delete(id: draft.id)
            }
            actionError = nil
        } catch {
            actionError = String(localized: "Entry deleted. Its unsaved edit is still here; retry cleanup from Drafts.")
        }
    }

    // MARK: Loading

    private func composeNote() {
        composingNote = JournalDraft(kind: .note)
    }

    private func unlock() async {
        guard lock.isLocked, !authenticating else { return }
        authenticating = true
        _ = await lock.authenticate()
        authenticating = false
    }

    private func clear() {
        timeline = JournalTimeline(entries: nil, retros: nil)
        versions = nil
        loaded = false
        journalEmpty = false
        hasFocusNotes = false
        loadFailed = false
        actionError = nil
        recoverableCount = 0
        unreadableDraftCount = 0
    }

    private func reload() {
        guard !lock.isLocked else { return }
        do {
            journalEmpty = try !repository.hasRecords()
            hasFocusNotes = try repository.hasRecords(kind: JournalEntry.kindFocus)
            if versions?.revision != repository.revision {
                versions = (repository.revision, try repository.versionRecordIDs())
            }
            let queries = filter.queries(search: search, versions: versions?.ids ?? [])
            var next = JournalTimeline(entries: queries.entries, retros: queries.retros, pageSize: Self.pageSize)
            try next.loadMore(from: repository)
            timeline = next
            loadFailed = false
            if actionError == Self.loadError { actionError = nil }
        } catch {
            // What already loaded stays; the failure becomes a row above it
            // (design-system section 8, Unavailable).
            if timeline.isEmpty {
                loadFailed = true
            } else {
                actionError = Self.loadError
            }
        }
        loaded = true
        refreshRecoverableCount()
    }

    private func loadMore() {
        guard !lock.isLocked else { return }
        do {
            try timeline.loadMore(from: repository)
            actionError = nil
        } catch {
            actionError = Self.loadError
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
