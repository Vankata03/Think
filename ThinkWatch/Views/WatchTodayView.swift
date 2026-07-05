//
//  WatchTodayView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchTodayView: View {
    @Environment(ProgressStore.self) private var progress

    private var quote: Quote { ContentLibrary.dailyQuote() }
    private var nextStep: PathStep? {
        let index = min(progress.pathCompletedDays, PathLibrary.deepFocus.steps.count - 1)
        guard PathLibrary.deepFocus.steps.indices.contains(index) else { return nil }
        return PathLibrary.deepFocus.steps[index]
    }

    private var dailyProgressCount: Int {
        var completed = 0
        if progress.completedTaskToday { completed += 1 }
        if progress.focusSessionsToday > 0 { completed += 1 }
        if progress.completedPathStepToday { completed += 1 }
        return completed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                quoteBlock
                progressBlock
                pathBlock
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Today")
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("Today")
                .font(.headline.weight(.semibold))
            Spacer()
            Label("\(progress.displayedStreak)", systemImage: "flame.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
                .accessibilityLabel("\(progress.displayedStreak) day streak")
        }
    }

    private var quoteBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(.yellow)
                .frame(width: 26, height: 3)
                .clipShape(Capsule())
            Text(quote.text)
                .font(.system(.callout, design: .serif).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Text(quote.author)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Daily reps")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(dailyProgressCount)/3")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.yellow)
            }
            ProgressView(value: Double(dailyProgressCount), total: 3)
                .tint(.yellow)
                .accessibilityLabel("Daily progress")
                .accessibilityValue("\(dailyProgressCount) of 3")
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var pathBlock: some View {
        if let nextStep {
            VStack(alignment: .leading, spacing: 5) {
                Label("Deep Focus", systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text("Day \(nextStep.id): \(nextStep.title)")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(nextStep.task)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    NavigationStack {
        WatchTodayView()
            .environment(ProgressStore(defaults: .standard))
    }
}
