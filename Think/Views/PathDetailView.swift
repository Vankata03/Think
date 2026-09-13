import SwiftUI

struct PathDetailView: View {
    let path: ThinkingPath
    @Environment(ProgressStore.self) private var progress
    @Environment(PomodoroTimer.self) private var timer
    @Environment(AppIntentRouter.self) private var router
    @Environment(JournalLock.self) private var journalLock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.haptics) private var haptics
    @State private var selectedRunID: UUID?
    @State private var showRestart = false

    private var run: PathRunProgress? {
        if let selectedRunID { return progress.runs(for: path.id).first { $0.id == selectedRunID } }
        return progress.activeRun(for: path.id)
    }
    private var completed: Int { run?.completedSteps ?? 0 }
    private var reviewing: Bool { selectedRunID != nil && selectedRunID != progress.activeRun(for: path.id)?.id }
    private var canComplete: Bool {
        !reviewing && progress.canCompletePathStep(pathID: path.id, totalSteps: path.steps.count)
    }

    var body: some View {
        List {
            Section {
                ProgressView(value: Double(completed), total: Double(max(1, path.steps.count))) {
                    Text("\(completed) of \(path.steps.count) days")
                }
                if let continuation = path.continuation { Text(continuation).font(.footnote).foregroundStyle(.secondary) }
            }
            if !reviewing, let step = path.currentStep(afterCompleted: completed) {
                Section("Day \(step.id) — \(step.title)") {
                    lesson(step)
                    Button {
                        withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
                            _ = progress.completePathStep(pathID: path.id, totalSteps: path.steps.count)
                        }
                        haptics.play(.success)
                    } label: {
                        Text(canComplete ? String(localized: "Mark day complete") : String(localized: "Come back tomorrow"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(Color("AccentColor"))
                    .foregroundStyle(.black).disabled(!canComplete)
                }
            } else if completed >= path.steps.count {
                Section { Label("Path completed. Begin again anytime.", systemImage: "checkmark.seal.fill") }
            }
            Section("All days") {
                ForEach(path.steps) { step in
                    NavigationLink {
                        List { Section("Day \(step.id) — \(step.title)") { lesson(step) } }
                            .navigationTitle(path.name).navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Day \(step.id) — \(step.title)", systemImage: step.id <= completed ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
            Section("Practice runs") {
                ForEach(Array(progress.runs(for: path.id).enumerated()), id: \.element.id) { index, value in
                    Button {
                        selectedRunID = value.id
                    } label: {
                        HStack {
                            Text("Run \(index + 1)")
                            Spacer()
                            Text("\(value.completedSteps)/\(value.totalSteps)")
                            if value.id == run?.id { Image(systemName: "checkmark") }
                        }
                    }
                }
                Button("Start a new run") { showRestart = true }
            }
        }
        .navigationTitle(path.name).navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("PathDetail.\(path.id)")
        .confirmationDialog("Start a new run?", isPresented: $showRestart) {
            Button("Start a new run") {
                let next = progress.startNewRun(pathID: path.id, totalSteps: path.steps.count)
                selectedRunID = next.id
            }
        } message: { Text("Your earlier runs and achievements stay saved. The new run starts at day one.") }
    }

    @ViewBuilder private func lesson(_ step: PathStep) -> some View {
        Text(step.lesson).font(.body).fontDesign(.serif)
        LabeledContent("Estimated task time", value: String(localized: "\(step.estimatedMinutes) min"))
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's task").font(.caption).foregroundStyle(.secondary)
            Text(step.task).accessibilityIdentifier("PathCurrentTask")
        }
        if let smaller = step.smallerTask {
            DisclosureGroup("A smaller version") { Text(smaller).font(.body) }
        }
        if let minutes = step.suggestedFocusMinutes {
            Button("Focus for \(minutes) min") {
                // Do not replace work already running. Route to it instead.
                if !timer.isRunning {
                    _ = timer.selectCustom(workMinutes: minutes, restMinutes: 5)
                    if !journalLock.isLocked { timer.setIntention(step.suggestedIntention) }
                }
                router.selectedTab = .focus
            }
            Text("Finishing the timer does not mark this task complete. Return here when you have done it.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
