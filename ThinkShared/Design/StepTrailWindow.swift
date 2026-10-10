//
//  StepTrailWindow.swift
//  ThinkShared
//

import SwiftUI

/// Which steps the trail window draws and how (paths.md section 3): seven
/// discs around today's step, clamped at the ends of the run, fading only
/// at an edge where the run continues.
nonisolated struct StepTrailWindowLayout: Equatable {
    static let width = 7

    var totalSteps: Int
    var doneSteps: Int
    /// The step open today, or nil in the hero's done form.
    var todayStep: Int?

    /// Today's step, or the step just done when nothing is open.
    private var centre: Int { todayStep ?? max(1, doneSteps) }

    var steps: [Int] {
        guard totalSteps > 0 else { return [] }
        let first = min(max(1, centre - Self.width / 2), max(1, totalSteps - Self.width + 1))
        return Array(first...min(totalSteps, first + Self.width - 1))
    }

    var fadesLeading: Bool { (steps.first ?? 1) > 1 }
    var fadesTrailing: Bool { (steps.last ?? totalSteps) < totalSteps }

    func state(of step: Int) -> StepDisc.State {
        if step <= doneSteps { return .done }
        return step == todayStep ? .next : .later
    }

    /// The window's VoiceOver value, also carried by the hero.
    var accessibilityValue: String {
        String(
            localized: "\(doneSteps) of \(totalSteps) steps done", table: "Design",
            comment: "Paths trail window: steps done in the run, for VoiceOver.")
    }
}

/// The step trail's small form, drawn only in the Paths list hero. At
/// accessibility sizes it yields to "n of m done" over a bar.
struct StepTrailWindow: View {
    var layout: StepTrailWindowLayout

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 26

    /// The share of the row each fading edge takes.
    private static let fade = 0.12

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                linearForm
            } else {
                discs
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Steps", tableName: "Design", comment: "Paths trail window label for VoiceOver."))
        .accessibilityValue(layout.accessibilityValue)
    }

    private var discs: some View {
        HStack(spacing: 0) {
            ForEach(layout.steps, id: \.self) { step in
                if step != layout.steps.first { Spacer(minLength: ThinkSpacing.xs) }
                StepDisc(state: layout.state(of: step), mark: .number(step), diameter: diameter, style: .stepTrail)
            }
        }
        .background {
            Rectangle()
                .fill(ThinkColor.track)
                .frame(height: 3)
                // The track runs on past an edge where the run continues.
                .padding(.leading, layout.fadesLeading ? 0 : diameter / 2)
                .padding(.trailing, layout.fadesTrailing ? 0 : diameter / 2)
        }
        // Room for the today disc's halo, which reaches 5pt past the disc,
        // so the mask does not clip it.
        .padding(6)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: layout.fadesLeading ? .clear : .black, location: 0),
                    .init(color: .black, location: layout.fadesLeading ? Self.fade : 0),
                    .init(color: .black, location: layout.fadesTrailing ? 1 - Self.fade : 1),
                    .init(color: layout.fadesTrailing ? .clear : .black, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var linearForm: some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.s) {
            Text(
                "\(layout.doneSteps) of \(layout.totalSteps) done", tableName: "Design",
                comment: "Paths trail window at accessibility sizes: steps done in the run."
            )
            .font(.think(.numeral))
            .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: Double(layout.doneSteps), total: Double(max(1, layout.totalSteps)))
                .tint(ThinkColor.accent)
        }
    }
}

#Preview("Window") {
    VStack(spacing: ThinkSpacing.xl) {
        StepTrailWindow(layout: .init(totalSteps: 21, doneSteps: 0, todayStep: 1))
        StepTrailWindow(layout: .init(totalSteps: 21, doneSteps: 9, todayStep: 10))
        StepTrailWindow(layout: .init(totalSteps: 21, doneSteps: 20, todayStep: 21))
        StepTrailWindow(layout: .init(totalSteps: 21, doneSteps: 5, todayStep: nil))
    }
    .padding()
    .background(ThinkColor.surface)
}
