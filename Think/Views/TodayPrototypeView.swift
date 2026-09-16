//
//  TodayPrototypeView.swift
//  Think
//
//  PROTOTYPE — throwaway. Answers "K with captions and numerals" for the
//  Today redesign ticket (#73). Lives on branch prototype/today-sun-arc
//  only; never merged. One screen, no persistence beyond what the real
//  stores already do. A "Prototype" toolbar menu scrubs the hour and the
//  ritual state so every day phase can be judged on device.
//

import SwiftUI
import SwiftData

private enum ArcState { case done, next, later }

/// `accent` from design/design-system.md: fills only, black ink on top.
private func accentFill(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 1.0, green: 0.831, blue: 0.2) : Color(red: 0.949, green: 0.769, blue: 0.11)
}

struct TodayPrototypeView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(FavoritesStore.self) private var favorites
    @Environment(JournalLock.self) private var lock
    @Environment(JournalRepository.self) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics

    @State private var practice = ContentLibrary.dailyPractice()
    @State private var day = CivilDay.today()

    // Prototype levers. Real stores stay untouched except the move toggle.
    @State private var hourOverride: Double? = nil
    /// nil = real stores; 0...3 = pretend this many acts are done, in ritual order.
    @State private var doneOverride: Int? = nil

    @State private var answerEditor: JournalDraft?
    @State private var showingRetro = false
    @State private var showingShare = false
    @State private var showingStreak = false
    @State private var openRecord: OpenRecord?

    private enum Act: CaseIterable { case question, move, retro }
    private enum OpenRecord: Identifiable, Hashable {
        case answer(JournalRepository.EntrySnapshot), retro(JournalRepository.RetroSnapshot)
        var id: PersistentIdentifier { switch self { case .answer(let e): e.id; case .retro(let r): r.id } }
        static func == (a: Self, b: Self) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    private var now: Date {
        guard let hourOverride else { return .now }
        let h = Int(hourOverride), m = Int((hourOverride - Double(h)) * 60)
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now
    }
    private var hour: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }
    private var isEvening: Bool { hour >= 20 }
    private var answered: Bool { doneOverride.map { $0 >= 1 } ?? progress.activities(on: now).contains(.answer) }
    private var moveDone: Bool { doneOverride.map { $0 >= 2 } ?? progress.isMoveCompleted(practiceID: practice.id, at: now) }
    private var retroDone: Bool { doneOverride.map { $0 >= 3 } ?? progress.activities(on: now).contains(.retro) }

    private var nextAct: Act? {
        if !answered { return .question }
        if !moveDone { return .move }
        if isEvening && !retroDone { return .retro }
        return nil
    }
    private func state(of act: Act) -> ArcState {
        switch act {
        case .question: answered ? .done : (nextAct == .question ? .next : .later)
        case .move: moveDone ? .done : (nextAct == .move ? .next : .later)
        case .retro: retroDone ? .done : (nextAct == .retro ? .next : .later)
        }
    }
    private var doneCount: Int { Act.allCases.filter { state(of: $0) == .done }.count }
    private var ink: Color { Color.accessibleAccent(for: colorScheme) }
    private var fill: Color { accentFill(colorScheme) }
    private var stacks: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    dayGraphic
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    lineBlock
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }
                Section {
                    if let nextAct {
                        actPanel(nextAct)
                    } else {
                        completeRow
                    }
                }
                Section {
                    ForEach(Act.allCases.filter { $0 != nextAct }, id: \.self) { act in
                        if state(of: act) == .done || act != .retro || isEvening {
                            statusRow(act)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SavedLinesPrototypeView() } label: {
                        Label("Saved lines", systemImage: "bookmark")
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingStreak = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "flame")
                            Text("\(progress.displayedStreak)")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(ink)
                    }
                    .accessibilityLabel("\(progress.displayedStreak) day streak")
                }
                ToolbarItem(placement: .topBarLeading) { prototypeMenu }
            }
            .animation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion), value: nextAct)
            .animation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion), value: hourOverride)
            .animation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion), value: doneOverride)
            .sheet(item: $answerEditor) { JournalEditor(draft: $0) }
            .sheet(isPresented: $showingRetro) { RetroSheet() }
            .sheet(isPresented: $showingShare) { ShareCardSheet(quote: practice.quote) }
            .sheet(isPresented: $showingStreak) { StreakCalendarSheet() }
            .navigationDestination(item: $openRecord) { record in
                switch record {
                case .answer(let e):
                    RecordPrototypeDetail(title: "Question of the day", sections: [(e.prompt, e.text)],
                                          date: e.updatedAt ?? e.date, draft: JournalDraft.editing(e))
                case .retro(let r):
                    RecordPrototypeDetail(title: "Evening retro",
                                          sections: [("What went well", r.wentWell), ("What to improve", r.improve), ("Tomorrow", r.tomorrow)],
                                          date: r.updatedAt ?? r.date, draft: JournalDraft.editing(r))
                }
            }
        }
    }

    // MARK: - Day graphic

    @ViewBuilder
    private var dayGraphic: some View {
        if stacks {
            linearDay
        } else {
            SunArc(hour: hour, states: Act.allCases.map { state(of: $0) }, ink: ink, fill: fill, reduceMotion: reduceMotion) {
                VStack(spacing: 2) {
                    Text("\(now.formatted(.dateTime.weekday(.wide))) · \(doneCount) of 3")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(now, format: .dateTime.hour().minute())
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your day. \(doneCount) of 3 done. Now \(now.formatted(.dateTime.hour().minute())).")
        }
    }

    /// Accessibility sizes: the arc yields to a bar and three rows.
    private var linearDay: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(doneCount) of 3").font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                Spacer()
                Text(now, format: .dateTime.hour().minute()).font(.headline).foregroundStyle(.secondary)
            }
            ProgressView(value: min(max((hour - 6) / 16, 0), 1)).tint(fill)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Line

    private var lineBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(practice.quote.text)
                .font(.system(.title, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                if let attribution = practice.quote.attribution {
                    Text(attribution).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(favorites.isFavorite(practice.quote) ? "Remove from saved lines" : "Save this line",
                       systemImage: favorites.isFavorite(practice.quote) ? "bookmark.fill" : "bookmark") {
                    haptics.play(.selection)
                    withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
                        _ = favorites.toggle(practice.quote)
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.body)
                .frame(minWidth: 44, minHeight: 44)
                Button("Share", systemImage: "square.and.arrow.up") { showingShare = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.body)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    // MARK: - Next act panel

    private func actPanel(_ act: Act) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(panelTitle(act), systemImage: symbol(act))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ink)
            Text(panelText(act))
                .font(act == .question ? .system(.title3, design: .serif) : .body)
                .fixedSize(horizontal: false, vertical: true)
            Button(panelButton(act), systemImage: symbol(act)) { perform(act) }
                .buttonStyle(.glassProminent)
                .tint(fill)
                .foregroundStyle(Color.prominentButtonForeground(for: colorScheme))
                .controlSize(.large)
        }
        .padding(.vertical, 6)
    }

    private var completeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Practice complete").font(.headline)
                Text("Day \(progress.displayedStreak) of your streak.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    /// Done rows open what was written: the answer and the retro push their
    /// detail; the move is a fact, not a door, so its row is static and the
    /// only way back is a trailing swipe "Undo" for a mistaken tap.
    @ViewBuilder
    private func statusRow(_ act: Act) -> some View {
        let done = state(of: act) == .done
        let label = HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : symbol(act))
                .foregroundStyle(done ? Color.green : Color.secondary)
                .font(.body)
            Text(rowText(act, done: done))
                .foregroundStyle(done ? .primary : .secondary)
            Spacer()
        }
        if done && act != .move {
            Button { open(act) } label: { label }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
        } else if done {
            label.swipeActions(edge: .trailing) {
                Button("Undo", systemImage: "arrow.uturn.backward") { toggleMove() }.tint(.secondary)
            }
        } else {
            label
        }
    }

    private func open(_ act: Act) {
        Task {
            if lock.isLocked, await lock.authenticate() == false { return }
            switch act {
            case .question:
                // One answer a day: the newest edit is the answer, older versions are not shown.
                if let a = try? repository.answer(for: day) {
                    let latest = a.all.max { ($0.updatedAt ?? $0.date) < ($1.updatedAt ?? $1.date) } ?? a.primary
                    openRecord = .answer(latest)
                }
            case .retro:
                if let r = try? repository.retro(for: day) { openRecord = .retro(r.primary) }
            case .move: break
            }
        }
    }

    // MARK: - Copy and actions

    private func symbol(_ act: Act) -> String {
        switch act { case .question: "questionmark.bubble"; case .move: "figure.walk"; case .retro: "moon.stars" }
    }
    private func panelTitle(_ act: Act) -> String {
        switch act { case .question: "Next · Question of the day"; case .move: "Next · Today's move"; case .retro: "Next · Evening retro" }
    }
    private func panelText(_ act: Act) -> String {
        switch act { case .question: practice.question; case .move: practice.action; case .retro: "How did the day go? Two minutes, three lines." }
    }
    private func panelButton(_ act: Act) -> String {
        switch act { case .question: "Write answer"; case .move: "Done"; case .retro: "Begin retro" }
    }
    private func rowText(_ act: Act, done: Bool) -> String {
        switch (act, done) {
        case (.question, true): "Question answered"
        case (.question, false): "Question of the day"
        case (.move, true): "Move done"
        case (.move, false): "Today's move · after the question"
        case (.retro, true): "Retro written"
        case (.retro, false): "Evening retro · 20:00"
        }
    }
    private func perform(_ act: Act) {
        haptics.play(.selection)
        switch act {
        case .question:
            let context = JournalDraft.Context(civilDay: day, practiceID: practice.id, promptSnapshot: practice.question)
            answerEditor = JournalDraft(kind: .answer, context: context)
        case .move: toggleMove()
        case .retro: showingRetro = true
        }
    }
    private func toggleMove() {
        if let n = doneOverride { doneOverride = n >= 2 ? 1 : 2; haptics.play(.success); return }
        let done = moveDone
        haptics.play(done ? .selection : .success)
        withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
            progress.setMoveCompleted(!done, practiceID: practice.id, at: .now)
        }
    }

    // MARK: - Prototype levers

    private var prototypeMenu: some View {
        Menu {
            Section("Hour") {
                ForEach([8.5, 14.2, 21.1, 21.7], id: \.self) { h in
                    Button(String(format: "%02d:%02d", Int(h), Int((h - Double(Int(h))) * 60))) { hourOverride = h }
                }
                Button("Real time") { hourOverride = nil }
            }
            Section("Ritual") {
                ForEach(0...3, id: \.self) { n in Button("\(n) done") { doneOverride = n } }
                Button("Real state") { doneOverride = nil }
            }
        } label: {
            Label("Prototype", systemImage: "slider.horizontal.3")
        }
    }
}

// MARK: - Sun arc

/// The day as a half circle from 06:00 to 22:00, filling with the accent as
/// time passes. Three markers sit where the ritual acts live; the sun rides
/// at the current hour. Captions under the markers name the acts.
private struct SunArc<Center: View>: View {
    var hour: Double
    var states: [ArcState]
    var ink: Color
    var fill: Color
    var reduceMotion: Bool
    @ViewBuilder var center: () -> Center

    private var fraction: Double { min(max((hour - 6) / 16, 0), 1) }
    private let marks: [(t: Double, symbol: String, name: LocalizedStringKey)] = [
        (0.18, "questionmark.bubble", "Question"), (0.5, "figure.walk", "Move"), (0.82, "moon.stars", "Retro")
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let r = min(w / 2 - 30, 132)
            let c = CGPoint(x: w / 2, y: r + 42)
            ZStack {
                Circle().trim(from: 0.5, to: 1)
                    .stroke(Color(.separator), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: r * 2, height: r * 2).position(c)
                Circle().trim(from: 0.5, to: 0.5 + fraction / 2)
                    .stroke(fill, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: r * 2, height: r * 2).position(c)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: fraction)
                sun.modifier(ArcPosition(fraction: fraction, center: c, radius: r))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: fraction)
                ForEach(Array(marks.enumerated()), id: \.offset) { i, m in
                    let p = point(m.t, c: c, r: r)
                    marker(i, symbol: m.symbol).position(p)
                    caption(i, m.name, at: p)
                }
                center().position(x: c.x, y: c.y - 40)
                Text("06:00").font(.caption2).foregroundStyle(.secondary).position(x: c.x - r, y: c.y + 22)
                Text("22:00").font(.caption2).foregroundStyle(.secondary).position(x: c.x + r, y: c.y + 22)
            }
        }
        .frame(height: 212)
    }

    /// Captions sit outside the curve: above-left of the question marker,
    /// above the move marker, above-right of the retro marker.
    @ViewBuilder
    private func caption(_ i: Int, _ name: LocalizedStringKey, at p: CGPoint) -> some View {
        let text = Text(name).font(.caption2.weight(.semibold)).foregroundStyle(captionColor(i))
        switch i {
        case 0: text.position(x: p.x - 16, y: p.y - 28)
        case 1: text.position(x: p.x, y: p.y - 28)
        default: text.position(x: p.x + 16, y: p.y - 28)
        }
    }

    private func point(_ t: Double, c: CGPoint, r: CGFloat) -> CGPoint {
        let a = Double.pi * (1 - t)
        return CGPoint(x: c.x + r * cos(a), y: c.y - r * sin(a))
    }

    private var sun: some View {
        ZStack {
            Circle().fill(fill.opacity(0.25)).frame(width: 30, height: 30)
            Circle().fill(fill).frame(width: 18, height: 18)
        }
    }

    private func captionColor(_ i: Int) -> Color {
        switch states[i] { case .done: .green; case .next: ink; case .later: .secondary }
    }

    @ViewBuilder
    private func marker(_ i: Int, symbol: String) -> some View {
        switch states[i] {
        case .done:
            ZStack {
                Circle().fill(.green).frame(width: 28, height: 28)
                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.black)
            }
        case .next:
            ZStack {
                Circle().fill(fill).frame(width: 28, height: 28)
                Image(systemName: symbol).font(.caption.weight(.semibold)).foregroundStyle(.black)
            }
        case .later:
            ZStack {
                Circle().fill(Color(.systemGroupedBackground)).frame(width: 26, height: 26)
                Circle().stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: 26, height: 26)
                Image(systemName: symbol).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Saved lines

/// Saved lines are just the lines: text and attribution, no practice behind
/// them. Swipe to remove, long-press to share.
struct SavedLinesPrototypeView: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.haptics) private var haptics
    @State private var sharedQuote: Quote?

    var body: some View {
        List {
            ForEach(favorites.favorites) { quote in
                VStack(alignment: .leading, spacing: 6) {
                    Text(quote.text)
                        .font(.system(.title2, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                    if let attribution = quote.attribution {
                        Text(attribution).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .contextMenu {
                    Button("Share", systemImage: "square.and.arrow.up") { sharedQuote = quote }
                    Button("Remove", systemImage: "bookmark.slash", role: .destructive) { favorites.remove(quote) }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        haptics.play(.selection)
                        favorites.remove(quote)
                    } label: { Label("Remove", systemImage: "bookmark.slash") }
                }
            }
        }
        .overlay {
            if favorites.isEmpty {
                ContentUnavailableView("Lines you keep appear here.", systemImage: "text.quote")
            }
        }
        .navigationTitle("Saved lines")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharedQuote) { ShareCardSheet(quote: $0) }
    }
}

/// Positions a view on the day arc at `fraction` (0 = 06:00, 1 = 22:00) and
/// animates along the curve, because `fraction` is the animatable value,
/// not the resulting point.
private struct ArcPosition: ViewModifier, Animatable {
    var fraction: Double
    var center: CGPoint
    var radius: CGFloat

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func body(content: Content) -> some View {
        let a = Double.pi * (1 - fraction)
        content.position(x: center.x + radius * cos(a), y: center.y - radius * sin(a))
    }
}

// MARK: - Record detail

/// Read-only detail for today's answer or retro: the prompt in serif, the
/// text under it, the time it was written. No practice door, no version list.
/// Edit is the only action; it opens the same editor Today uses.
struct RecordPrototypeDetail: View {
    var title: LocalizedStringKey
    var sections: [(String, String)]
    var date: Date
    var draft: JournalDraft?
    @State private var editing: JournalDraft?

    var body: some View {
        List {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, pair in
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(pair.0).font(.system(.title3, design: .serif))
                        Text(pair.1.isEmpty ? "—" : pair.1).font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                Text("Written \(date.formatted(.dateTime.hour().minute()))")
                    .font(.footnote).foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Edit", systemImage: "pencil") { editing = draft }.disabled(draft == nil)
            }
        }
        .sheet(item: $editing) { JournalEditor(draft: $0) }
    }
}
