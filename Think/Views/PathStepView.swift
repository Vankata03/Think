import SwiftUI

/// One step of a path (design/paths.md section 6), pushed from a trail
/// disc, a step row or the next row. Read only: today's action lives on
/// path detail. A step not open yet shows its title and waits.
struct PathStepView: View {
    let path: ThinkingPath
    let number: Int

    @Environment(ProgressStore.self) private var progress
    @ScaledMetric(relativeTo: .body) private var lessonSpacing: CGFloat = 4

    private var step: PathStep? {
        path.steps.indices.contains(number - 1) ? path.steps[number - 1] : nil
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let detail = PathDetail(path: path, progress: progress, now: context.date)
            List {
                Section {
                    VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                        Text(step?.title ?? "")
                            .font(.think(.stepTitle))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(
                            "Step \(number) of \(path.steps.count) · \(path.name)",
                            comment: "Path step page: the step's place in the run and the path's name."
                        )
                        .font(.think(.secondary))
                        .foregroundStyle(ThinkColor.secondaryLabel)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                switch detail.page(for: number) {
                case .done(let date):
                    content
                    if let date {
                        Section {
                            Label {
                                Text(
                                    "Completed \(date.formatted(date: .abbreviated, time: .omitted))",
                                    comment: "Path step page: the day a done step was completed.")
                            } icon: {
                                Image(systemName: ThinkSymbol.done)
                                    .foregroundStyle(ThinkColor.success)
                            }
                            .accessibilityIdentifier("PathStepCompleted")
                        }
                    }
                case .today:
                    content
                case .opensNext(let tomorrow):
                    waiting(
                        tomorrow
                            ? String(localized: "Opens tomorrow at \(detail.openingTime()).", comment: "Path step page: a step that opens tomorrow. The argument is 06:00 in the locale's time format.")
                            : String(
                                localized: "Opens today at \(detail.openingTime()).",
                                comment: "Path step page: a step that opens before 06:00 today. The argument is 06:00 in the locale's time format."))
                case .opensAfter(let previous):
                    waiting(
                        String(
                            localized: "Opens after step \(previous).",
                            comment: "Path step page: a later step. The argument is the number of the step before it."))
                }
            }
        }
        .navigationTitle(Text("Step \(number)", comment: "Path step page title."))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("PathStep.\(number)")
    }

    @ViewBuilder
    private var content: some View {
        if let step {
            Section {
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
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("PathStepTask")
            }
        }
    }

    /// The Locked state for a step not open yet (design system section 8).
    private func waiting(_ line: String) -> some View {
        Section {
            ContentUnavailableView {
                Label(line, systemImage: ThinkSymbol.lock)
            }
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("PathStepLocked")
        }
    }
}
