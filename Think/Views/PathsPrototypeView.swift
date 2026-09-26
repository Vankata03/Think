//
//  PathsPrototypeView.swift
//  Think
//
//  PROTOTYPE, throwaway. Answers "Paths list and Path detail: step progress legibility"
//  (#75, map #68): variant K (thin segmented track) against variant L (trail window plus a
//  full trail as the step index). Both put today's step in a hero on the list and carry the
//  same mark on top of the step card on detail, so Complete step stays high.
//  In-memory state only. Launch arguments pick the variant, stage and screen:
//    -proto.variant K|L  -proto.stage ready|doneToday|finished  -proto.route list|detail|step7|locked
//  or use the "Prototype" menu in the Paths toolbar. Never merge.
//

import SwiftUI

// MARK: - State

enum ProtoVariant: String, CaseIterable, Identifiable {
    case K, L, M, N
    var id: String { rawValue }
    var label: String {
        switch self {
        case .K: "K · Track + rows"
        case .L: "L · Window + full trail"
        case .M: "M · Window + rows"
        case .N: "N · Full trail only"
        }
    }
    /// Detail draws the compact mark on the step card.
    var markOnCard: Bool { self != .N }
    /// Detail's step index is the full trail rather than rows.
    var fullTrail: Bool { self == .L || self == .N }
}

enum ProtoStage: String, CaseIterable, Identifiable {
    case ready, doneToday, finished
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ready: "Step ready"
        case .doneToday: "Done today"
        case .finished: "Run finished"
        }
    }
}

enum ProtoRoute: Hashable {
    case path(String)
    case step(String, Int)
}

@Observable
final class PathsProtoModel {
    var variant: ProtoVariant
    var done: Int
    var doneToday: Bool
    var finishedRuns: Int
    var navPath: [ProtoRoute] = []

    let deepFocus = PathLibrary.deepFocus
    let clearThinking = PathLibrary.clearThinking
    var total: Int { deepFocus.steps.count }
    var isFinished: Bool { done >= total }
    var clearThinkingUnlocked: Bool { finishedRuns > 0 }
    /// Index of the step open today, nil when today's step is done or the run is finished.
    var current: Int? { doneToday || isFinished ? nil : done }

    init() {
        let defaults = UserDefaults.standard
        variant = ProtoVariant(rawValue: defaults.string(forKey: "proto.variant") ?? "") ?? .L
        done = 4; doneToday = false; finishedRuns = 0
        apply(ProtoStage(rawValue: defaults.string(forKey: "proto.stage") ?? "") ?? .ready)
    }

    func apply(_ stage: ProtoStage) {
        switch stage {
        case .ready: done = 4; doneToday = false; finishedRuns = 0
        case .doneToday: done = 5; doneToday = true; finishedRuns = 0
        case .finished: done = total; doneToday = false; finishedRuns = 1
        }
    }

    func complete() {
        guard current != nil else { return }
        done += 1; doneToday = true
        if isFinished { finishedRuns += 1 }
    }

    func undo() {
        guard doneToday else { return }
        if isFinished { finishedRuns -= 1 }
        done -= 1; doneToday = false
    }

    func beginAgain() { done = 0; doneToday = false }

    static let dates = ["19 Sep", "20 Sep", "22 Sep", "25 Sep", "26 Sep"]
    func completedDate(_ index: Int) -> String {
        index < Self.dates.count ? Self.dates[index] : "\(index + 7) Oct"
    }
}

// MARK: - Colours (design-system section 2 values, local to the prototype)

private extension Color {
    static let protoAccent = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.831, blue: 0.2, alpha: 1)
        : UIColor(red: 0.949, green: 0.769, blue: 0.11, alpha: 1) })
    static let protoAccentInk = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.831, blue: 0.2, alpha: 1)
        : UIColor(red: 0.431, green: 0.361, blue: 0.02, alpha: 1) })
}

// MARK: - Paths list

struct PathsPrototypeView: View {
    @State private var model = PathsProtoModel()

    var body: some View {
        NavigationStack(path: $model.navPath) {
            List {
                Section { hero }
                Section {
                    NavigationLink(value: ProtoRoute.path(model.deepFocus.id)) {
                        pathRow(model.deepFocus, symbol: "scope",
                                detail: model.isFinished ? "Completed \(model.finishedRuns) time" : nil,
                                trailing: "\(model.done)/\(model.total)")
                    }
                    NavigationLink(value: ProtoRoute.path(model.clearThinking.id)) {
                        if model.clearThinkingUnlocked {
                            pathRow(model.clearThinking, symbol: "lightbulb", detail: nil, trailing: "0/7")
                        } else {
                            pathRow(model.clearThinking, symbol: "lock", detail: "Finish Deep focus first", trailing: nil)
                        }
                    }
                } header: {
                    Text("All paths")
                } footer: {
                    Text("Two more paths are in development.")
                }
            }
            .navigationTitle("Paths")
            .toolbar { ToolbarItem(placement: .topBarLeading) { protoMenu } }
            .navigationDestination(for: ProtoRoute.self) { route in
                switch route {
                case .path(let id) where id == model.deepFocus.id:
                    PathDetailPrototype(model: model)
                case .path:
                    if model.clearThinkingUnlocked {
                        ContentUnavailableView("Clear thinking", systemImage: "lightbulb",
                                               description: Text("Unlocked. Not drawn in this prototype."))
                    } else {
                        LockedPathPrototype { model.navPath = [.path(model.deepFocus.id)] }
                    }
                case .step(_, let index):
                    StepPrototype(model: model, index: index)
                }
            }
        }
        .onAppear {
            switch UserDefaults.standard.string(forKey: "proto.route") {
            case "detail": model.navPath = [.path(model.deepFocus.id)]
            case "step7": model.navPath = [.path(model.deepFocus.id), .step(model.deepFocus.id, 6)]
            case "locked": model.navPath = [.path(model.clearThinking.id)]
            default: break
            }
        }
    }

    @ViewBuilder private var hero: some View {
        let path = model.deepFocus
        NavigationLink(value: ProtoRoute.path(path.id)) {
            VStack(alignment: .leading, spacing: 10) {
                ProtoMark(model: model, compact: true)
                    .padding(.bottom, 4)
                if let index = model.current {
                    let step = path.steps[index]
                    Label("Today on Deep focus · Step \(index + 1)", systemImage: "circle.inset.filled")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.protoAccentInk)
                    Text(step.title).font(.title2.weight(.semibold))
                    Text(step.lesson).font(.body).fontDesign(.serif).foregroundStyle(.secondary).lineLimit(2)
                    Text("\(step.estimatedMinutes) min").font(.subheadline.weight(.semibold)).foregroundStyle(Color.protoAccentInk)
                } else if model.isFinished {
                    Label("Deep focus completed", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                    Text("Clear thinking is open").font(.title2.weight(.semibold))
                    Text("A seven-step introduction to clearer decisions.").foregroundStyle(.secondary)
                } else {
                    Label("Step \(model.done) done", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                    Text(path.steps[model.done].title).font(.title2.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Opens tomorrow at 06:00").foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
    }

    private func pathRow(_ path: ThinkingPath, symbol: String, detail: String?, trailing: String?) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(path.name)
                    if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
                }
            } icon: { Image(systemName: symbol).foregroundStyle(symbol == "lock" ? .secondary : .primary) }
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).fontDesign(.rounded).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }

    private var protoMenu: some View {
        Menu {
            Picker("Variant", selection: $model.variant) {
                ForEach(ProtoVariant.allCases) { Text($0.label).tag($0) }
            }
            Section("Stage") {
                ForEach(ProtoStage.allCases) { stage in
                    Button(stage.label) { model.apply(stage) }
                }
            }
        } label: {
            Label("Prototype", systemImage: "slider.horizontal.3")
        }
    }
}

// MARK: - Path detail

struct PathDetailPrototype: View {
    @Bindable var model: PathsProtoModel
    @Environment(AppIntentRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showSmaller = false

    var body: some View {
        let path = model.deepFocus
        ScrollViewReader { proxy in
        List {
            Text(path.name).font(.largeTitle.bold())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

            if let index = model.current {
                Section { stepCard(path.steps[index], index: index) }
            } else if model.isFinished {
                Section {
                    if model.variant.markOnCard { ProtoMark(model: model, compact: true).padding(.vertical, 6) }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Path completed.", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.headline)
                        Text("Completed \(model.finishedRuns) time · last on 11 Oct")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("Begin again") { withAnimation { model.beginAgain() } }
                        .foregroundStyle(Color.protoAccentInk)
                }
            } else {
                Section {
                    if model.variant.markOnCard { ProtoMark(model: model, compact: true).padding(.vertical, 6) }
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Step \(model.done) done")
                            Text(path.steps[model.done - 1].title).font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    .swipeActions(edge: .trailing) {
                        Button("Undo") { withAnimation { model.undo() } }.tint(.orange)
                    }
                    NavigationLink(value: ProtoRoute.step(path.id, model.done)) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Step \(model.done + 1) · \(path.steps[model.done].title)")
                                Text("Opens tomorrow at 06:00").font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "lock").foregroundStyle(.secondary) }
                    }
                }
            }

            Section("Steps") {
                if model.variant.fullTrail && !typeSize.isAccessibilitySize {
                    FullTrail(model: model)
                        .padding(.vertical, 8)
                        .id("steps")
                } else {
                    ForEach(Array(path.steps.enumerated()), id: \.offset) { index, step in
                        NavigationLink(value: ProtoRoute.step(path.id, index)) { stepRow(step, index: index) }
                            .id(index == 0 ? "steps" : "step\(index)")
                    }
                }
            }
        }
        .onAppear {
            if UserDefaults.standard.string(forKey: "proto.scroll") == "steps" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { proxy.scrollTo("steps", anchor: .top) }
            }
        }
        }
        .navigationTitle(path.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepCard(_ step: PathStep, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.variant.markOnCard { ProtoMark(model: model, compact: true) }
            Label("Today · Step \(index + 1) of \(model.total) · \(step.estimatedMinutes) min", systemImage: "circle.inset.filled")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.protoAccentInk)
            Text(step.title).font(.title2.weight(.semibold))
            Text(step.lesson).font(.body).fontDesign(.serif).lineSpacing(4)
            VStack(alignment: .leading, spacing: 4) {
                Text("Task").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Text(step.task).fixedSize(horizontal: false, vertical: true)
            }
            if let smaller = step.smallerTask {
                DisclosureGroup("A smaller version", isExpanded: $showSmaller) {
                    Text(smaller).padding(.top, 4)
                }
                .tint(Color.protoAccentInk)
            }
            VStack(spacing: 8) {
                if let minutes = step.suggestedFocusMinutes {
                    Button { router.selectedTab = .focus } label: {
                        Text("Focus for \(minutes) min").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large).tint(.primary)
                }
                Button { withAnimation { model.complete() } } label: {
                    Text("Complete step").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(Color.protoAccent).foregroundStyle(.black)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    private func stepRow(_ step: PathStep, index: Int) -> some View {
        let isDone = index < model.done
        let isToday = index == model.current
        let isNext = index == model.done && model.doneToday
        return HStack {
            Label {
                (Text("\(index + 1)  ").foregroundStyle(.secondary).monospacedDigit() + Text(step.title))
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundStyle(isDone || isToday ? .primary : .secondary)
            } icon: {
                Image(systemName: isDone ? "checkmark.circle.fill" : isToday ? "circle.inset.filled" : "lock")
                    .foregroundStyle(isDone ? Color.green : isToday ? Color.protoAccent : Color.secondary)
            }
            Spacer()
            Text(isDone ? model.completedDate(index) : isToday ? "Today" : isNext ? "Tomorrow, 06:00" : "")
                .font(.subheadline).foregroundStyle(isToday ? Color.protoAccentInk : .secondary)
        }
    }
}

// MARK: - Step page and locked path

struct StepPrototype: View {
    let model: PathsProtoModel
    let index: Int

    var body: some View {
        let step = model.deepFocus.steps[index]
        let open = index < model.done || index == model.current
        List {
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(.title.bold())
                Text("Step \(index + 1) of \(model.total) · Deep focus").foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            if open {
                Section {
                    Text(step.lesson).fontDesign(.serif).lineSpacing(4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Task").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        Text(step.task)
                    }
                    if index < model.done {
                        Label("Completed \(model.completedDate(index))", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label(index == model.done ? "Opens tomorrow at 06:00." : "Opens after step \(index).", systemImage: "lock")
                } description: {
                    Text("One step a day. It waits until you are ready.")
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Step \(index + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LockedPathPrototype: View {
    let openPrevious: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Finish Deep focus first.", systemImage: "lock")
        } description: {
            Text("A seven-step introduction to clearer decisions.")
        } actions: {
            Button("Open Deep focus", action: openPrevious)
                .buttonStyle(.bordered).tint(Color.protoAccentInk)
        }
        .navigationTitle("Clear thinking")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Marks

/// The compact mark: K's segmented track or L's trail window. Linear at accessibility sizes.
struct ProtoMark: View {
    let model: PathsProtoModel
    let compact: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    (Text("\(model.done)").font(.title2.weight(.semibold)).fontDesign(.rounded)
                     + Text(" of \(model.total) done").foregroundStyle(.secondary))
                    ProgressView(value: Double(model.done), total: Double(model.total)).tint(Color.protoAccent)
                }
            } else if model.variant == .K {
                SegmentedTrack(total: model.total, done: model.done, current: model.current)
            } else {
                TrailWindow(total: model.total, done: model.done, current: model.current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Deep focus progress")
        .accessibilityValue("\(model.done) of \(model.total) steps done")
    }
}

struct SegmentedTrack: View {
    let total: Int, done: Int, current: Int?
    @ScaledMetric private var height: CGFloat = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                let shape = RoundedRectangle(cornerRadius: 1.5)
                if index < done {
                    shape.fill(Color.protoAccent)
                } else if index == current {
                    shape.strokeBorder(Color.protoAccent, lineWidth: 1.5)
                } else {
                    shape.fill(Color(.tertiarySystemFill))
                }
            }
        }
        .frame(height: height)
    }
}

struct StepDisc: View {
    enum Kind { case done, today, later }
    let kind: Kind
    let number: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            switch kind {
            case .done:
                Circle().fill(.green)
                Image(systemName: "checkmark").font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.black)
            case .today:
                Circle().fill(Color.protoAccent.opacity(0.25)).frame(width: size + 10, height: size + 10)
                Circle().fill(Color.protoAccent)
                Text("\(number)").font(.system(size: size * 0.46, weight: .bold, design: .rounded)).foregroundStyle(.black)
            case .later:
                Circle().fill(Color(.secondarySystemGroupedBackground))
                Circle().strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
                Text("\(number)").font(.system(size: size * 0.42, design: .rounded)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

private func discKind(_ index: Int, done: Int, current: Int?) -> StepDisc.Kind {
    index < done ? .done : index == current ? .today : .later
}

/// Seven steps around today, fading out where the run continues.
struct TrailWindow: View {
    let total: Int, done: Int, current: Int?
    @ScaledMetric private var size: CGFloat = 26
    private let window = 7

    var body: some View {
        let focus = current ?? min(done, total - 1)
        let start = max(0, min(total - window, focus - 3))
        GeometryReader { geo in
            let gap = (geo.size.width - size) / CGFloat(window - 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill)).frame(height: 3)
                ForEach(0..<window, id: \.self) { k in
                    let index = start + k
                    StepDisc(kind: discKind(index, done: done, current: current), number: index + 1, size: size)
                        .offset(x: CGFloat(k) * gap)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: size + 10)
        .mask {
            LinearGradient(stops: [
                .init(color: start > 0 ? .clear : .black, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88),
                .init(color: start + window < total ? .clear : .black, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
        }
    }
}

/// The whole run as a snaking trail, seven to a row; each disc opens its step.
struct FullTrail: View {
    let model: PathsProtoModel
    @ScaledMetric private var size: CGFloat = 30
    private let columns = 7

    var body: some View {
        let total = model.total
        let rows = (total + columns - 1) / columns
        let rowGap = size + 20
        GeometryReader { geo in
            let inset: CGFloat = 18
            let gap = (geo.size.width - size - 2 * inset) / CGFloat(columns - 1)
            let point: (Int) -> CGPoint = { index in
                let row = index / columns, col = index % columns
                let x = inset + size / 2 + CGFloat(row.isMultiple(of: 2) ? col : columns - 1 - col) * gap
                return CGPoint(x: x, y: size / 2 + 5 + CGFloat(row) * rowGap)
            }
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: point(0))
                    for index in 1..<total {
                        let a = point(index - 1), b = point(index)
                        if a.y == b.y { p.addLine(to: b) } else {
                            let bulge: CGFloat = a.x > geo.size.width / 2 ? 24 : -24
                            p.addCurve(to: b, control1: CGPoint(x: a.x + bulge, y: a.y), control2: CGPoint(x: b.x + bulge, y: b.y))
                        }
                    }
                }
                .stroke(Color(.tertiarySystemFill), lineWidth: 3)
                ForEach(0..<total, id: \.self) { index in
                    Button { model.navPath.append(.step(model.deepFocus.id, index)) } label: {
                        StepDisc(kind: discKind(index, done: model.done, current: model.current), number: index + 1, size: size)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Step \(index + 1), \(model.deepFocus.steps[index].title)")
                    .position(point(index))
                }
            }
        }
        .frame(height: CGFloat(rows - 1) * rowGap + size + 10)
    }
}
