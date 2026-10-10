import SwiftUI

/// The Paths tab (design/paths.md section 4): today's step as the hero, then
/// one row per available path. `PathsList` decides what shows.
struct PathsView: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        NavigationStack {
            // The next step opens at 06:00; re-read the list as the clock moves.
            TimelineView(.everyMinute) { context in
                let list = PathsList(progress: progress, now: context.date)
                List {
                    if let hero = list.hero {
                        Section {
                            NavigationLink(value: hero.path.id) {
                                PathsHero(hero: hero)
                            }
                            .accessibilityLabel(hero.accessibilityLabel())
                            .accessibilityValue(hero.window.accessibilityValue)
                            .accessibilityIdentifier("PathsHero")
                        }
                    }
                    Section {
                        ForEach(list.rows) { row in
                            NavigationLink(value: row.path.id) {
                                PathRow(row: row)
                            }
                            .accessibilityIdentifier("Path.\(row.path.id)")
                        }
                    } header: {
                        Text("All paths")
                    } footer: {
                        if list.pathsInDevelopment > 0 {
                            Text(
                                "\(list.pathsInDevelopment) more paths are in development.",
                                comment: "Paths list footer: how many paths are not available yet.")
                        }
                    }
                }
            }
            .navigationTitle("Paths")
            .navigationDestination(for: String.self) { id in
                if let path = PathLibrary.all.first(where: { $0.id == id }) {
                    PathDetailView(path: path)
                }
            }
        }
    }
}

/// Today's step (section 4.1), or its done form once the step is done.
private struct PathsHero: View {
    let hero: PathsList.Hero

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var lessonSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.s) {
            StepTrailWindow(layout: hero.window)
                .padding(.bottom, ThinkSpacing.xs)
            switch hero.form {
            case .open(let number):
                Label {
                    Text(
                        "Today on \(hero.path.name) · Step \(number)",
                        comment: "Paths hero caption: path name and today's step number.")
                } icon: {
                    Image(systemName: ThinkSymbol.pathStepToday)
                }
                .font(.think(.secondary).weight(.semibold))
                .foregroundStyle(ThinkColor.accentInk)
                if let step = hero.step {
                    Text(step.title)
                        .font(.think(.stepTitle))
                        .fixedSize(horizontal: false, vertical: true)
                    // Truncates after a few words at accessibility sizes, so it yields.
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text(step.lesson)
                            .font(.think(.lesson))
                            .lineSpacing(lessonSpacing)
                            .foregroundStyle(ThinkColor.secondaryLabel)
                            .lineLimit(2)
                    }
                    Text("\(step.estimatedMinutes) min")
                        .font(.think(.secondary).weight(.semibold))
                        .foregroundStyle(ThinkColor.accentInk)
                }
            case .done(let number, _):
                Label {
                    Text("Step \(number) done", comment: "Paths hero after today's step is done.")
                } icon: {
                    Image(systemName: ThinkSymbol.done)
                        .foregroundStyle(ThinkColor.success)
                }
                .font(.think(.secondary).weight(.semibold))
                if let step = hero.step {
                    Text(step.title)
                        .font(.think(.stepTitle))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(ThinkColor.secondaryLabel)
                }
                Text(hero.opening())
                    .font(.think(.secondary))
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
        }
        .padding(.vertical, ThinkSpacing.s)
    }
}

/// One available path under "All paths" (section 4.2).
private struct PathRow: View {
    let row: PathsList.Row

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label {
                VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                    Text(row.path.name)
                    if let detail {
                        Text(detail)
                            .font(.think(.secondary))
                            .foregroundStyle(ThinkColor.secondaryLabel)
                    }
                    if dynamicTypeSize.isAccessibilitySize, let progress { progress }
                }
            } icon: {
                if case .locked = row.state {
                    Image(systemName: ThinkSymbol.lock)
                        .foregroundStyle(ThinkColor.secondaryLabel)
                } else {
                    Image(systemName: row.path.icon)
                        .foregroundStyle(ThinkColor.accentInk)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize, let progress {
                Spacer(minLength: ThinkSpacing.s)
                progress
            }
        }
    }

    private var detail: LocalizedStringKey? {
        switch row.state {
        case .inRun(_, _, let open?): "Step \(open) today"
        case .inRun: nil
        case .finished(let times): "Completed \(times) times"
        case .locked(let previous): "Finish \(previous.name) first"
        }
    }

    /// "done/total" for a path in a run.
    private var progress: Text? {
        guard case .inRun(let done, let total, _) = row.state else { return nil }
        return Text("\(done)/\(total)")
            .font(.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit())
            .foregroundStyle(ThinkColor.secondaryLabel)
    }
}

#Preview {
    PathsView()
        .environment(ProgressStore())
        .environment(PomodoroTimer())
        .environment(AppIntentRouter.shared)
}
