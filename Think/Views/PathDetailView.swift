import SwiftUI

/// Path detail (design/paths.md section 5): the full name, today's step
/// card or its done rows, the finished or locked state, and the full trail.
/// `PathDetail` decides what shows.
struct PathDetailView: View {
    let path: ThinkingPath
    @Binding var stack: [PathsRoute]

    @Environment(ProgressStore.self) private var progress

    var body: some View {
        // The next step opens at 06:00; re-read the detail as the clock moves.
        TimelineView(.everyMinute) { context in
            let detail = PathDetail(path: path, progress: progress, now: context.date)
            if case .locked(let previous) = detail.status {
                ContentUnavailableView {
                    Label {
                        Text(
                            "Finish \(previous.name) first.",
                            comment: "Locked path detail: the path to finish before this one opens.")
                    } icon: {
                        Image(systemName: ThinkSymbol.lock)
                    }
                    // On the line, not the screen: an outer identifier would
                    // replace the button's own.
                    .accessibilityIdentifier("PathDetail.\(path.id)")
                } actions: {
                    Button {
                        stack = [.path(previous.id)]
                    } label: {
                        Text("Open \(previous.name)", comment: "Locked path detail: opens the path before this one.")
                    }
                    .thinkButton(.secondary)
                    .accessibilityIdentifier("OpenPreviousPath")
                }
            } else {
                PathDetailList(detail: detail, stack: $stack)
                    .accessibilityIdentifier("PathDetail.\(path.id)")
            }
        }
        .navigationTitle(path.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PathDetailList: View {
    let detail: PathDetail
    @Binding var stack: [PathsRoute]

    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.haptics) private var haptics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var path: ThinkingPath { detail.path }
    /// Reduce Motion cuts from the card to the done rows (paths.md section 11).
    private var stateAnimation: Animation? {
        reduceMotion ? nil : ThinkMotion.enter
    }

    var body: some View {
        List {
            // The full name, which a long `de` or `bg` name truncates in the bar.
            Section {
                Text(path.name)
                    .font(.think(.title))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            switch detail.status {
            case .open(let number):
                if let step = step(number) {
                    Section {
                        StepCard(step: step, number: number, total: path.steps.count, complete: complete)
                    }
                    .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
                }
            case .done(let number, let tomorrow, let canUndo):
                Section {
                    doneRow(number, canUndo: canUndo)
                    if let next = step(number + 1) {
                        NavigationLink(value: PathsRoute.step(path: path.id, number: number + 1)) {
                            nextRow(next, number: number + 1, tomorrow: tomorrow)
                        }
                        .accessibilityIdentifier("PathNextRow")
                    }
                }
                .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
            case .finished(let times, let lastOn):
                Section {
                    finished(times: times, lastOn: lastOn)
                }
            case .locked:
                EmptyView()
            }
            Section {
                if dynamicTypeSize.isAccessibilitySize {
                    ForEach(detail.steps) { step in
                        NavigationLink(value: PathsRoute.step(path: path.id, number: step.number)) {
                            StepRow(step: step, detail: detail)
                        }
                        .accessibilityIdentifier("PathStepRow.\(step.number)")
                    }
                } else {
                    StepTrailView(
                        discs: detail.steps.map { step in
                            .init(
                                number: step.number, state: discState(step.state),
                                label: step.accessibilityLabel, value: detail.accessibilityValue(of: step))
                        },
                        onSelect: { stack.append(.step(path: path.id, number: $0)) }
                    )
                    // Narrow side insets keep seven 44pt targets on a 375pt
                    // screen (paths.md section 12).
                    .listRowInsets(
                        EdgeInsets(
                            top: ThinkSpacing.s, leading: ThinkSpacing.s, bottom: ThinkSpacing.s,
                            trailing: ThinkSpacing.s)
                    )
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Steps", comment: "Path detail: the section holding the full step trail.")
            }
        }
    }

    private func step(_ number: Int) -> PathStep? {
        path.steps.indices.contains(number - 1) ? path.steps[number - 1] : nil
    }

    private func discState(_ state: PathDetail.StepState) -> StepDisc.State {
        switch state {
        case .done: .done
        case .today: .next
        case .opensNext, .later: .later
        }
    }

    private func complete() {
        withAnimation(stateAnimation) {
            if progress.completePathStep(pathID: path.id, totalSteps: path.steps.count) {
                haptics.play(.success)
            }
        }
    }

    /// Static: no chevron, no tap. Same-day trailing swipe undoes it.
    private func doneRow(_ number: Int, canUndo: Bool) -> some View {
        StatusRow {
            Image(systemName: ThinkSymbol.done)
                .foregroundStyle(ThinkColor.success)
        } title: {
            Text("Step \(number) done", comment: "Paths hero after today's step is done.")
        } detail: {
            Text(step(number)?.title ?? "")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("PathDoneRow")
        .swipeActions(edge: .trailing) {
            if canUndo {
                Button("Undo", systemImage: ThinkSymbol.undo) {
                    haptics.play(.selection)
                    withAnimation(stateAnimation) {
                        _ = progress.undoPathStep(pathID: path.id)
                    }
                }
                .accessibilityIdentifier("UndoPathStep")
            }
        }
    }

    private func nextRow(_ step: PathStep, number: Int, tomorrow: Bool) -> some View {
        StatusRow {
            Image(systemName: ThinkSymbol.lock)
                .foregroundStyle(ThinkColor.secondaryLabel)
        } title: {
            Text("Step \(number) · \(step.title)", comment: "Path detail: the next step's number and title.")
        } detail: {
            Text(detail.opening(tomorrow: tomorrow))
        }
    }

    /// "Completed n times · last on date", or just the count when the run is undated.
    /// Two strings, so the count keeps its plural rule from the list row.
    private func completedLine(times: Int, lastOn: Date?) -> String {
        let count = String(
            localized: "Completed \(times) times", comment: "Paths list row: how many runs of a finished path are done.")
        guard let lastOn else { return count }
        let last = String(
            localized: "last on \(lastOn.formatted(date: .abbreviated, time: .omitted))",
            comment: "Path detail, finished: the date the last run was finished, after the run count.")
        return "\(count) · \(last)"
    }

    /// The Begin-again state as a section above the trail (paths.md section 5.4).
    private func finished(times: Int, lastOn: Date?) -> some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.s) {
            Label {
                Text("Path completed.", comment: "Path detail: the run is finished.")
                    .font(.think(.heading))
                    .accessibilityIdentifier("PathFinished")
            } icon: {
                Image(systemName: path.icon)
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
            Text(verbatim: completedLine(times: times, lastOn: lastOn))
                .font(.think(.secondary))
                .foregroundStyle(ThinkColor.secondaryLabel)
            if let continuation = path.continuation {
                Text(continuation)
                    .font(.think(.secondary))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                withAnimation(stateAnimation) {
                    _ = progress.startNewRun(pathID: path.id, totalSteps: path.steps.count)
                }
            } label: {
                Text("Begin again", comment: "Path detail: starts a new run of a finished path.")
            }
            .thinkButton(.secondary)
            .tint(ThinkColor.accentInk)
            .padding(.top, ThinkSpacing.xs)
            .accessibilityIdentifier("BeginAgain")
        }
        .padding(.vertical, ThinkSpacing.s)
    }
}

/// A symbol on the title's first baseline with a secondary line under the
/// title, so both lines share one leading edge at every text size.
private struct StatusRow<Icon: View, Title: View, Detail: View>: View {
    @ViewBuilder var icon: Icon
    @ViewBuilder var title: Title
    @ViewBuilder var detail: Detail

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ThinkSpacing.m) {
            icon
            VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                title
                    .fixedSize(horizontal: false, vertical: true)
                detail
                    .font(.think(.secondary))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Today's step card (paths.md section 5.1).
private struct StepCard: View {
    let step: PathStep
    let number: Int
    let total: Int
    let complete: () -> Void

    @Environment(PomodoroTimer.self) private var timer
    @Environment(AppIntentRouter.self) private var router
    @Environment(JournalLock.self) private var journalLock
    @ScaledMetric(relativeTo: .body) private var lessonSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.m) {
            Label {
                Text(
                    "Today · Step \(number) of \(total) · \(step.estimatedMinutes) min",
                    comment: "Path detail step card caption: step number, run length and minutes.")
            } icon: {
                Image(systemName: ThinkSymbol.pathStepToday)
            }
            .font(.think(.secondary).weight(.semibold))
            .foregroundStyle(ThinkColor.accentInk)
            Text(step.title)
                .font(.think(.stepTitle))
                .fixedSize(horizontal: false, vertical: true)
            Text(step.lesson)
                .font(.think(.lesson))
                .lineSpacing(lessonSpacing)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                Text("Task", comment: "Path step: the heading over the step's task.")
                    .font(.think(.caption).weight(.semibold))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                Text(step.task)
                    .font(.think(.body))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("PathCurrentTask")
            }
            if let smaller = step.smallerTask {
                DisclosureGroup("A smaller version") {
                    Text(smaller)
                        .font(.think(.body))
                        .foregroundStyle(ThinkColor.label)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, ThinkSpacing.xs)
                }
                .tint(ThinkColor.accentInk)
                .foregroundStyle(ThinkColor.accentInk)
            }
            // Stacked, full width, same height and shape (PDT-2, PDT-5).
            VStack(spacing: ThinkSpacing.s) {
                if let minutes = step.suggestedFocusMinutes {
                    Button {
                        timer.prepareForPathStep(
                            workMinutes: minutes, title: step.title, journalLocked: journalLock.isLocked)
                        router.selectedTab = .focus
                    } label: {
                        Text("Focus for \(minutes) min", comment: "Path step card: sets up Focus for the step.")
                            .frame(maxWidth: .infinity)
                    }
                    .thinkButton(.secondary)
                    .accessibilityIdentifier("FocusForStep")
                }
                Button(action: complete) {
                    Text("Complete step", comment: "Path step card: the one primary action.")
                        .frame(maxWidth: .infinity)
                }
                .thinkButton(.primary)
                .accessibilityIdentifier("CompleteStep")
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .padding(.top, ThinkSpacing.xs)
        }
        .padding(.vertical, ThinkSpacing.s)
    }
}

/// One step at accessibility sizes, where the trail yields to rows
/// (paths.md section 5.3). The symbol sits on the title's first baseline.
private struct StepRow: View {
    let step: PathDetail.Step
    let detail: PathDetail

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ThinkSpacing.s) {
            symbol
            Text(step.number, format: .number)
                .foregroundStyle(ThinkColor.secondaryLabel)
            VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                Text(step.title)
                    .fixedSize(horizontal: false, vertical: true)
                value
                    .font(.think(.secondary))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.accessibilityLabel)
        .accessibilityValue(detail.accessibilityValue(of: step))
    }

    @ViewBuilder
    private var symbol: some View {
        switch step.state {
        case .done:
            Image(systemName: ThinkSymbol.done).foregroundStyle(ThinkColor.success)
        case .today:
            Image(systemName: ThinkSymbol.pathStepToday).foregroundStyle(ThinkColor.accentInk)
        case .opensNext, .later:
            Image(systemName: ThinkSymbol.lock).foregroundStyle(ThinkColor.secondaryLabel)
        }
    }

    @ViewBuilder
    private var value: some View {
        switch step.state {
        case .done(let date?):
            Text(date, format: .dateTime.day().month())
                .foregroundStyle(ThinkColor.secondaryLabel)
        case .today:
            Text("Today")
                .foregroundStyle(ThinkColor.accentInk)
        case .opensNext(let tomorrow):
            Group {
                if tomorrow {
                    Text("Tomorrow, \(detail.openingTime())", comment: "Path detail step row: when the next step opens.")
                } else {
                    Text(
                        "Today, \(detail.openingTime())",
                        comment: "Path detail step row: when the next step opens, before 06:00 on that day.")
                }
            }
            .foregroundStyle(ThinkColor.secondaryLabel)
        case .done(nil), .later:
            EmptyView()
        }
    }
}
