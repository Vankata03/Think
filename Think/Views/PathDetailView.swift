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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if progress.isPathUnlocked(path.id) {
                    ProgressView(value: Double(completed), total: Double(max(1, path.steps.count))) {
                        Text("\(completed) of \(path.steps.count) days")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .tint(Color("AccentColor"))
                    if !reviewing, let step = path.currentStep(afterCompleted: completed) {
                        VStack(alignment: .leading, spacing: 24) {
                            lesson(step)
                            Button {
                                withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
                                    if progress.completePathStep(pathID: path.id, totalSteps: path.steps.count) {
                                        haptics.play(.success)
                                    }
                                }
                            } label: {
                                Text(canComplete ? String(localized: "Mark day complete") : String(localized: "Come back tomorrow"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).controlSize(.large).tint(Color("AccentColor"))
                            .foregroundStyle(.black).disabled(!canComplete)
                        }
                        .padding(24)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                    } else if completed >= path.steps.count {
                        Label("Path completed. Begin again anytime.", systemImage: "checkmark.seal.fill")
                        if let continuation = path.continuation {
                            Text(continuation).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    DisclosureGroup("All days") {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(path.steps) { step in
                                NavigationLink {
                                    ScrollView { lesson(step).padding(24) }
                                        .navigationTitle(path.name).navigationBarTitleDisplayMode(.inline)
                                } label: {
                                    Label("Day \(step.id) — \(step.title)", systemImage: step.id <= completed ? "checkmark.circle.fill" : "circle")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }.padding(.top, 20)
                    }
                    DisclosureGroup("Practice runs") {
                        VStack(spacing: 20) {
                            ForEach(Array(progress.runs(for: path.id).enumerated()), id: \.element.id) { index, value in
                                Button { selectedRunID = value.id } label: {
                                    HStack {
                                        Text("Run \(index + 1)")
                                        Spacer()
                                        Text("\(value.completedSteps)/\(value.totalSteps)")
                                        if value.id == run?.id { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                            Button("Start a new run") { showRestart = true }
                        }.padding(.top, 20)
                    }
                } else if let previous = progress.prerequisite(for: path.id) {
                    Label("Complete \(previous.name) to unlock", systemImage: "lock.fill")
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(path.name).navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("PathDetail.\(path.id)")
        .confirmationDialog("Start a new run?", isPresented: $showRestart) {
            Button("Start a new run") {
                let next = progress.startNewRun(pathID: path.id, totalSteps: path.steps.count)
                selectedRunID = next.id
            }
        } message: { Text("Your earlier runs and achievements stay saved. The new run starts at day one.") }
    }

    private func lesson(_ step: PathStep) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Day \(step.id)")
                    Spacer()
                    Label("\(step.estimatedMinutes) min", systemImage: "clock")
                }
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text(step.title).font(.title2.bold())
            }
            Text(step.lesson).font(.body).fontDesign(.serif).lineSpacing(4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's task").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(step.task).accessibilityIdentifier("PathCurrentTask")
            }
            if let smaller = step.smallerTask {
                DisclosureGroup("A smaller version") {
                    Text(smaller).font(.body).padding(.top, 8)
                }.font(.subheadline)
            }
            if let minutes = step.suggestedFocusMinutes {
                Button("Focus for \(minutes) min") {
                    if !timer.isRunning {
                        _ = timer.selectCustom(workMinutes: minutes, restMinutes: 5)
                        if !journalLock.isLocked { timer.setIntention(step.suggestedIntention) }
                    }
                    router.selectedTab = .focus
                }.buttonStyle(.bordered).controlSize(.large)
            }
        }
    }
}
