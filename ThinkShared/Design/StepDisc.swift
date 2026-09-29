//
//  StepDisc.swift
//  ThinkShared
//

import SwiftUI

/// The disc that marks one act on the day arc or one step on the Paths
/// trail, so a finished act and a finished step look the same
/// (today.md section 3, paths.md section 3).
struct StepDisc: View {
    enum State: Equatable, Sendable {
        /// `success` fill with a black check.
        case done
        /// `accent` fill: the act that is next, or the step open today.
        case next
        /// Dashed `secondaryLabel` ring: an act for later, a step not open yet.
        case later
    }

    enum Mark: Equatable {
        /// The act's symbol, on the day arc.
        case symbol(String)
        /// The step number, on the trail.
        case number(Int)
    }

    enum Style {
        /// Later discs sit on the screen `background` with a 1.5pt ring.
        case dayArc
        /// Later discs sit on `surface` with a 1.2pt ring; the next disc
        /// carries an `accent` halo.
        case stepTrail
    }

    var state: State
    var mark: Mark
    var diameter: CGFloat
    var style: Style

    var body: some View {
        ZStack {
            switch state {
            case .done:
                Circle().fill(ThinkColor.success)
                glyph(Image(systemName: "checkmark"), weight: .bold)
                    .foregroundStyle(ThinkColor.accentOnFill)
            case .next:
                if style == .stepTrail {
                    Circle()
                        .fill(ThinkColor.accent.opacity(0.25))
                        .frame(width: diameter + 10, height: diameter + 10)
                }
                Circle().fill(ThinkColor.accent)
                markGlyph.foregroundStyle(ThinkColor.accentOnFill)
            case .later:
                Circle().fill(style == .dayArc ? ThinkColor.background : ThinkColor.surface)
                Circle().strokeBorder(
                    ThinkColor.secondaryLabel,
                    style: StrokeStyle(lineWidth: style == .dayArc ? 1.5 : 1.2, dash: [3, 2.5])
                )
                markGlyph.foregroundStyle(ThinkColor.secondaryLabel)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private var markGlyph: some View {
        switch mark {
        case .symbol(let name):
            glyph(Image(systemName: name), weight: .semibold)
        case .number(let number):
            glyph(Text(number, format: .number), weight: .semibold, design: .rounded)
                .monospacedDigit()
        }
    }

    /// Glyphs follow a text style but stop growing before they outgrow the
    /// disc; past that size the graphics yield to their linear forms.
    private func glyph(_ content: some View, weight: Font.Weight, design: Font.Design? = nil) -> some View {
        content
            .font(.system(.caption, design: design, weight: weight))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

#Preview("States") {
    VStack(spacing: ThinkSpacing.xl) {
        HStack(spacing: ThinkSpacing.l) {
            StepDisc(state: .done, mark: .symbol(ThinkSymbol.question), diameter: 28, style: .dayArc)
            StepDisc(state: .next, mark: .symbol(ThinkSymbol.move), diameter: 28, style: .dayArc)
            StepDisc(state: .later, mark: .symbol(ThinkSymbol.retro), diameter: 28, style: .dayArc)
        }
        HStack(spacing: ThinkSpacing.l) {
            StepDisc(state: .done, mark: .number(4), diameter: 30, style: .stepTrail)
            StepDisc(state: .next, mark: .number(5), diameter: 30, style: .stepTrail)
            StepDisc(state: .later, mark: .number(6), diameter: 30, style: .stepTrail)
        }
    }
    .padding()
}
