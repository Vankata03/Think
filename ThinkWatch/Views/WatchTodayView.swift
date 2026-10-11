//
//  WatchTodayView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchTodayView: View {
    @Environment(ProgressStore.self) private var progress

    private var quote: Quote { ContentLibrary.dailyQuote() }
    private var pathFinished: Bool {
        progress.activeRun(for: PathLibrary.deepFocus.id)?.isComplete == true
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
                .accessibilityLabel(progress.displayedStreak == 1
                                    ? String(localized: "1 day streak")
                                    : String(localized: "\(progress.displayedStreak) day streak"))
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
            if let attribution = quote.attribution {
                Text(attribution)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
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
                Text("\(progress.dailyPracticeProgressCount)/4")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.yellow)
            }
            ProgressView(value: Double(progress.dailyPracticeProgressCount), total: 4)
                .tint(.yellow)
                .accessibilityLabel("Daily progress")
                .accessibilityValue(String(localized: "\(progress.dailyPracticeProgressCount) of 4"))
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Rebuilt each minute so the next step opens at 06:00 without a sync (design/paths.md section 9).
    private var pathBlock: some View {
        TimelineView(.everyMinute) { context in
            pathBlock(WatchPathStep(progress: progress, now: context.date))
        }
    }

    @ViewBuilder
    private func pathBlock(_ nextStep: WatchPathStep?) -> some View {
        if let nextStep {
            VStack(alignment: .leading, spacing: 5) {
                Label {
                    Text(PathLibrary.deepFocus.name)
                } icon: {
                    Image(systemName: "scope")
                }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text("Step \(nextStep.number) · \(nextStep.step.title)")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(stepDetail(nextStep))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        } else if pathFinished {
            Label {
                Text("\(PathLibrary.deepFocus.name) completed")
            } icon: {
                Image(systemName: "checkmark.seal.fill")
            }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

extension WatchTodayView {
    /// The step's task while it is open; otherwise when it opens, in the phone's wording.
    private func stepDetail(_ nextStep: WatchPathStep) -> String {
        guard let opensAt = nextStep.opensAt else { return nextStep.step.task }
        let time = opensAt.formatted(date: .omitted, time: .shortened)
        return nextStep.opensTomorrow
            ? String(localized: "Opens tomorrow at \(time)", comment: "Watch Today: when Deep focus's next step opens.")
            : String(
                localized: "Opens today at \(time)",
                comment: "Watch Today: when Deep focus's next step opens, before 06:00 on the day it opens.")
    }
}

#Preview {
    NavigationStack {
        WatchTodayView()
            .environment(ProgressStore(defaults: .standard))
    }
}
