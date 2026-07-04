//
//  PathDetailView.swift
//  Think
//

import SwiftUI

struct PathDetailView: View {
    let path: ThinkingPath
    @Environment(ProgressStore.self) private var progress

    private var completed: Int { progress.pathCompletedDays }
    private var isFinished: Bool { completed >= path.steps.count }
    private var currentStep: PathStep? {
        isFinished ? nil : path.steps[completed]
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
                    }
                    Button(progress.canCompletePathStepToday ? "Mark day complete" : "Come back tomorrow") {
                        progress.completePathStep()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!progress.canCompletePathStepToday)
                }
            } else {
                Section {
                    Label("Path completed. Begin again anytime.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            Section("All days") {
                ForEach(path.steps) { step in
                    HStack {
                        Image(systemName: icon(for: step))
                            .foregroundStyle(step.id <= completed ? .green : .secondary)
                        Text("Day \(step.id) — \(step.title)")
                            .font(.subheadline)
                            .foregroundStyle(step.id <= completed + 1 ? .primary : .secondary)
                    }
                }
            }
        }
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
