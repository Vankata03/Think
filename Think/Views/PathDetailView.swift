//
//  PathDetailView.swift
//  Think
//

import SwiftUI

struct PathDetailView: View {
    let path: ThinkingPath
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics

    private var prominentButtonForeground: Color {
        .prominentButtonForeground(for: colorScheme)
    }

    private var completed: Int { progress.pathCompletedDays }
    private var currentStep: PathStep? {
        path.currentStep(afterCompleted: completed)
    }

    var body: some View {
        List {
            Section {
                ProgressView(value: Double(completed), total: Double(path.steps.count)) {
                    Text("\(completed) of \(path.steps.count) days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let step = currentStep {
                Section("Day \(step.id) — \(step.title)") {
                    Text(step.lesson)
                        .font(.body)
                        .fontDesign(.serif)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's task")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(step.task)
                            .font(.subheadline)
                            .accessibilityIdentifier("PathCurrentTask")
                    }
                    Button {
                        guard progress.canCompletePathStepToday else { return }
                        withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
                            progress.completePathStep()
                        }
                        haptics.play(.success)
                    } label: {
                        Text(progress.canCompletePathStepToday
                             ? String(localized: "Mark day complete")
                             : String(localized: "Come back tomorrow"))
                            .foregroundStyle(prominentButtonForeground)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.accentColor)
                    .disabled(!progress.canCompletePathStepToday)
                }
                .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
            } else {
                Section {
                    Label("Path completed. Begin again anytime.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
            }

            Section("All days") {
                ForEach(path.steps) { step in
                    HStack {
                        Image(systemName: icon(for: step))
                            .foregroundStyle(step.id <= completed ? .green : .secondary)
                            .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                        Text("Day \(step.id) — \(step.title)")
                            .font(.subheadline)
                            .foregroundStyle(step.id <= completed + 1 ? .primary : .secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PathDetail.\(path.id)")
        .navigationTitle(path.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func icon(for step: PathStep) -> String {
        if step.id <= completed { return "checkmark.circle.fill" }
        if step.id == completed + 1 { return "circle.dotted" }
        return "circle"
    }
}

#Preview {
    NavigationStack {
        PathDetailView(path: PathLibrary.deepFocus)
    }
    .environment(ProgressStore())
}
