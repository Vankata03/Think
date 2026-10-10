//
//  StepTrailView.swift
//  ThinkShared
//

import SwiftUI

/// Where each step of the full trail sits (paths.md section 3): seven to a
/// row, the first row left to right, the next right to left, so the run
/// snakes like the Paths symbol. A short returning row starts under the turn.
nonisolated struct StepTrailLayout: Equatable {
    static let perRow = 7

    var totalSteps: Int

    /// Each row as it is drawn, leading to trailing; nil is an empty column.
    var rows: [[Int?]] {
        guard totalSteps > 0 else { return [] }
        return stride(from: 1, through: totalSteps, by: Self.perRow).enumerated().map { index, first in
            let steps: [Int?] = Array(first...min(totalSteps, first + Self.perRow - 1))
            let padded = steps + Array(repeating: nil, count: Self.perRow - steps.count)
            return index.isMultiple(of: 2) ? padded : padded.reversed()
        }
    }
}

/// The whole run on path detail: every step as a disc on a 3pt track,
/// each disc a button that opens its step. Drawn only at default sizes;
/// path detail turns it into rows at accessibility sizes.
struct StepTrailView: View {
    struct Disc: Identifiable {
        var number: Int
        var state: StepDisc.State
        /// "Step n, title".
        var label: String
        /// "done", "today", "opens tomorrow at 06:00", "not open yet".
        var value: String
        var id: Int { number }
    }

    var discs: [Disc]
    var onSelect: (Int) -> Void

    @ScaledMetric(relativeTo: .body) private var preferredDiameter: CGFloat = 30
    @State private var width: CGFloat = 0

    /// The smallest tap target, including the spacing around the disc.
    private static let target: CGFloat = 44
    /// The today disc's halo reaches 5pt past the disc on each side.
    private static let halo: CGFloat = 10

    private var layout: StepTrailLayout { StepTrailLayout(totalSteps: discs.count) }
    private var column: CGFloat { width / CGFloat(StepTrailLayout.perRow) }
    /// The disc shrinks before the gap does, so neighbouring halos and
    /// targets never meet on a narrow screen or at a large text size.
    private var diameter: CGFloat {
        guard width > 0 else { return preferredDiameter }
        return max(20, min(preferredDiameter, column - Self.halo - 2))
    }
    private var rowHeight: CGFloat { max(Self.target, diameter + Self.halo) }
    private var rowSpacing: CGFloat { ThinkSpacing.m }

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, number in
                        if let number, let disc = discs.first(where: { $0.number == number }) {
                            button(disc)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(height: rowHeight)
            }
        }
        .background {
            StepTrailTrack(rows: layout.rows, rowHeight: rowHeight, rowSpacing: rowSpacing)
                .stroke(ThinkColor.track, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityElement(children: .contain)
    }

    private func button(_ disc: Disc) -> some View {
        Button {
            onSelect(disc.number)
        } label: {
            StepDisc(state: disc.state, mark: .number(disc.number), diameter: diameter, style: .stepTrail)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(disc.label)
        .accessibilityValue(disc.value)
        .accessibilityIdentifier("StepDisc.\(disc.number)")
    }
}

/// The track under the discs: a line through each row and a curve at the
/// row end that turns into the next row.
nonisolated private struct StepTrailTrack: Shape {
    var rows: [[Int?]]
    var rowHeight: CGFloat
    var rowSpacing: CGFloat

    func path(in rect: CGRect) -> Path {
        let column = rect.width / CGFloat(StepTrailLayout.perRow)
        func x(_ index: Int) -> CGFloat { column * (CGFloat(index) + 0.5) }
        let pitch = rowHeight + rowSpacing
        var path = Path()
        for (r, row) in rows.enumerated() {
            let filled = row.indices.filter { row[$0] != nil }
            guard let first = filled.first, let last = filled.last else { continue }
            let y = rowHeight / 2 + CGFloat(r) * pitch
            path.move(to: CGPoint(x: x(first), y: y))
            path.addLine(to: CGPoint(x: x(last), y: y))
            guard r + 1 < rows.count else { continue }
            // Even rows turn at the trailing edge, odd rows at the leading one.
            let turn = r.isMultiple(of: 2) ? StepTrailLayout.perRow - 1 : 0
            let outward: CGFloat = r.isMultiple(of: 2) ? 1 : -1
            let bulge = column * 0.6 * outward
            path.move(to: CGPoint(x: x(turn), y: y))
            path.addCurve(
                to: CGPoint(x: x(turn), y: y + pitch),
                control1: CGPoint(x: x(turn) + bulge, y: y),
                control2: CGPoint(x: x(turn) + bulge, y: y + pitch))
        }
        return path
    }
}

#Preview("Trail") {
    let states: [StepDisc.State] = Array(repeating: .done, count: 9) + [.next] + Array(repeating: .later, count: 11)
    List {
        StepTrailView(
            discs: states.enumerated().map { index, state in
                .init(number: index + 1, state: state, label: "Step \(index + 1)", value: "")
            },
            onSelect: { _ in })
    }
}
