//
//  DayArcView.swift
//  ThinkShared
//

import SwiftUI

/// Where everything on the day arc sits (today.md section 3). The arc is the
/// upper half of a circle from 06:00 on the left to 22:00 on the right.
nonisolated struct DayArcGeometry: Equatable {
    static let startHour = 6.0
    static let endHour = 22.0
    /// Question, move and retro: symmetric about the top of the arc. The
    /// retro sits at 20:00, the hour the retro act opens.
    static let markerHours: [Double] = [8, 14, 20]

    static let markerDiameter: CGFloat = 28
    static let sunDiameter: CGFloat = 18
    static let haloDiameter: CGFloat = 30
    /// The background ring that separates a marker from the sun and the stroke.
    static let markerGap: CGFloat = 2
    static let strokeWidth: CGFloat = 3
    static let maxRadius: CGFloat = 132
    /// Room above the top marker for its caption.
    static let topInset: CGFloat = 42
    /// Row height beyond the radius: the top inset plus the end labels.
    static let heightBeyondRadius: CGFloat = 78
    /// A caption's centre sits this far above its marker's centre.
    static let captionRise: CGFloat = 28
    /// The question and retro captions move this far outward, off the curve.
    static let captionShift: CGFloat = 16
    /// The centre text's centre sits this far above the circle's centre.
    static let centreTextRise: CGFloat = 40
    /// The 06:00 and 22:00 labels sit this far below the arc ends.
    static let endLabelDrop: CGFloat = 22

    var width: CGFloat

    /// The diameter is the content width minus 60pt, capped at a 132pt radius.
    var radius: CGFloat { max(0, min((width - 60) / 2, Self.maxRadius)) }
    var rowHeight: CGFloat { radius + Self.heightBeyondRadius }
    var center: CGPoint { CGPoint(x: width / 2, y: radius + Self.topInset) }

    /// 06:00 is 0 and 22:00 is 1; hours outside the day are clamped.
    static func fraction(forHour hour: Double) -> Double {
        min(max((hour - startHour) / (endHour - startHour), 0), 1)
    }

    static func hour(of date: Date, calendar: Calendar = .current) -> Double {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
    }

    func point(forHour hour: Double) -> CGPoint {
        ArcPosition.point(fraction: Self.fraction(forHour: hour), center: center, radius: radius)
    }

    /// The centre x for text of `width` that wants to sit at `x`, nudged
    /// inward so it stays inside a row `rowWidth` wide. A long caption on a
    /// narrow row ("Rückblick" beside the retro marker) moves in rather
    /// than past the edge.
    static func clampedCentre(_ x: CGFloat, width: CGFloat, within rowWidth: CGFloat) -> CGFloat {
        guard width < rowWidth else { return rowWidth / 2 }
        return min(max(x, width / 2), rowWidth - width / 2)
    }

    /// The sun is drawn under the markers. Its halo would ring a marker it
    /// passes, so the halo fades out from the moment it touches a marker
    /// until the sun's own disc does, and is gone while the disc overlaps.
    func haloOpacity(atHour hour: Double) -> Double {
        let sun = point(forHour: hour)
        let nearest = Self.markerHours
            .map { marker in
                let point = point(forHour: marker)
                return hypot(point.x - sun.x, point.y - sun.y)
            }
            .min() ?? .infinity
        let discTouches = (Self.markerDiameter + Self.sunDiameter) / 2
        let haloClears = (Self.markerDiameter + Self.haloDiameter) / 2
        return min(max((nearest - discTouches) / (haloClears - discTouches), 0), 1)
    }
}

/// The day as a half circle from 06:00 to 22:00, with the sun at the current
/// hour and a marker for each act of the ritual (design-system section 14).
/// Drawn live on Today and once, as a picture, on onboarding's first step.
///
/// Callers animate a marker's state change with `ThinkMotion.stateAnimation`;
/// the hour animates here.
struct DayArcView: View {
    struct States: Equatable {
        var question: StepDisc.State
        var move: StepDisc.State
        var retro: StepDisc.State

        var doneCount: Int {
            [question, move, retro].filter { $0 == .done }.count
        }
    }

    /// One act of the ritual as the arc draws it, in ritual order, matching
    /// `DayArcGeometry.markerHours`.
    private struct Marker {
        var symbol: String
        var caption: LocalizedStringResource
        /// Which way the caption moves off the curve: -1 left, 0 none, 1 right.
        var captionSide: CGFloat
        var state: KeyPath<States, StepDisc.State>
    }

    private static let markers = [
        Marker(symbol: ThinkSymbol.question, caption: LocalizedStringResource("Question", table: "Design"),
               captionSide: -1, state: \.question),
        Marker(symbol: ThinkSymbol.move, caption: LocalizedStringResource("Move", table: "Design"),
               captionSide: 0, state: \.move),
        Marker(symbol: ThinkSymbol.retro, caption: LocalizedStringResource("Retro", table: "Design"),
               captionSide: 1, state: \.retro),
    ]

    var hour: Double
    var states: States
    /// The clock behind the centre text. `nil` draws the picture form used
    /// by onboarding: no weekday, count or time in the centre.
    var now: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var width = CGFloat.infinity
    @ThinkSpacing.Scaled(ThinkSpacing.s) private var linearSpacing

    init(hour: Double, states: States, now: Date? = nil) {
        self.hour = hour
        self.states = states
        self.now = now
    }

    private var fraction: Double { DayArcGeometry.fraction(forHour: hour) }

    /// The sun and the elapsed stroke glide to a new hour; Reduce Motion cuts.
    private var hourAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.8)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                linearForm
            } else {
                arc
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Arc

    private var arc: some View {
        GeometryReader { proxy in
            let geometry = DayArcGeometry(width: proxy.size.width)
            let center = geometry.center
            let radius = geometry.radius
            ZStack {
                halfCircle(to: 1, center: center, radius: radius)
                    .stroke(ThinkColor.separator, style: stroke)
                halfCircle(to: fraction, center: center, radius: radius)
                    .stroke(ThinkColor.accent, style: stroke)
                sun(haloOpacity: geometry.haloOpacity(atHour: hour))
                    .arcPosition(fraction, center: center, radius: radius)
                ForEach(Array(zip(DayArcGeometry.markerHours, Self.markers).enumerated()), id: \.offset) { _, pair in
                    let (markerHour, marker) = pair
                    let point = geometry.point(forHour: markerHour)
                    disc(for: marker).position(point)
                    caption(for: marker)
                        .modifier(InsideRow(point: CGPoint(
                            x: point.x + marker.captionSide * DayArcGeometry.captionShift,
                            y: point.y - DayArcGeometry.captionRise
                        )))
                }
                if let now {
                    centreText(now).position(x: center.x, y: center.y - DayArcGeometry.centreTextRise)
                }
                endLabel(atHour: 6)
                    .modifier(InsideRow(point: CGPoint(x: center.x - radius, y: center.y + DayArcGeometry.endLabelDrop)))
                endLabel(atHour: 22)
                    .modifier(InsideRow(point: CGPoint(x: center.x + radius, y: center.y + DayArcGeometry.endLabelDrop)))
            }
            .animation(hourAnimation, value: fraction)
        }
        .frame(height: DayArcGeometry(width: width).rowHeight)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: DayArcGeometry.strokeWidth, lineCap: .round)
    }

    private func halfCircle(to fraction: Double, center: CGPoint, radius: CGFloat) -> some Shape {
        Circle()
            .trim(from: 0.5, to: 0.5 + fraction / 2)
            .size(width: radius * 2, height: radius * 2)
            .offset(x: center.x - radius, y: center.y - radius)
    }

    private func sun(haloOpacity: Double) -> some View {
        ZStack {
            Circle()
                .fill(ThinkColor.accent.opacity(0.25 * haloOpacity))
                .frame(width: DayArcGeometry.haloDiameter, height: DayArcGeometry.haloDiameter)
            Circle()
                .fill(ThinkColor.accent)
                .frame(width: DayArcGeometry.sunDiameter, height: DayArcGeometry.sunDiameter)
        }
    }

    /// A ring of the screen background around each marker lets the sun
    /// read as passing behind it instead of merging with it.
    private func disc(for marker: Marker) -> some View {
        StepDisc(
            state: states[keyPath: marker.state],
            mark: .symbol(marker.symbol),
            diameter: DayArcGeometry.markerDiameter,
            style: .dayArc
        )
        .background {
            Circle()
                .fill(ThinkColor.background)
                .padding(-DayArcGeometry.markerGap)
        }
    }

    /// Captions sit outside the curve so they never cross it: above and
    /// left of the question, above the move, above and right of the retro.
    private func caption(for marker: Marker) -> some View {
        Text(marker.caption)
            .font(.think(.graphicCaption))
            .foregroundStyle(captionColor(states[keyPath: marker.state]))
            .fixedSize()
    }

    private func captionColor(_ state: StepDisc.State) -> Color {
        switch state {
        case .done: ThinkColor.success
        case .next: ThinkColor.accentInk
        case .later: ThinkColor.secondaryLabel
        }
    }

    private func centreText(_ now: Date) -> some View {
        VStack(spacing: ThinkSpacing.xs) {
            Text(LocalizedStringResource(
                "\(now.formatted(.dateTime.weekday(.wide))) · \(states.doneCount) of 3",
                table: "Design"
            ))
            .font(.think(.caption))
            .fontWeight(.semibold)
            .foregroundStyle(ThinkColor.secondaryLabel)
            Text(now, format: .dateTime.hour().minute())
                .font(.think(.numeral))
        }
        .fixedSize()
    }

    private func endLabel(atHour clockHour: Int) -> some View {
        let date = Calendar.current.date(bySettingHour: clockHour, minute: 0, second: 0, of: now ?? .now) ?? .now
        return Text(date, format: .dateTime.hour().minute())
            .font(.think(.graphicCaption))
            .foregroundStyle(ThinkColor.secondaryLabel)
            .fixedSize()
    }

    // MARK: Accessibility sizes

    /// At accessibility sizes the arc yields to the count over a bar
    /// (design-system 13.7). The time is dropped; it wraps at AX3.
    private var linearForm: some View {
        VStack(alignment: .leading, spacing: linearSpacing) {
            Text(LocalizedStringResource("\(states.doneCount) of 3", table: "Design"))
                .font(.think(.numeral))
            ProgressView(value: fraction)
                .tint(ThinkColor.accent)
                .animation(hourAnimation, value: fraction)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityLabel: Text {
        guard let now else {
            return Text(LocalizedStringResource(
                "Your day: a question in the morning, a move by afternoon, a retro in the evening.",
                table: "Design"
            ))
        }
        return Text(LocalizedStringResource(
            "Your day. \(states.doneCount) of 3 done. Now \(now.formatted(.dateTime.hour().minute())).",
            table: "Design"
        ))
    }
}

/// Centres text on a point of the arc like `.position`, but keeps it inside
/// the row (`DayArcGeometry.clampedCentre`) and above the curve.
private struct InsideRow: ViewModifier {
    var point: CGPoint

    func body(content: Content) -> some View {
        InsideRowLayout(point: point) { content }
    }
}

private struct InsideRowLayout: Layout {
    var point: CGPoint

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let x = DayArcGeometry.clampedCentre(point.x, width: size.width, within: bounds.width)
            // Text nudged inward rises as far as it moved, so a caption
            // pushed toward the curve still clears it.
            let y = point.y - abs(point.x - x)
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                anchor: .center,
                proposal: ProposedViewSize(size)
            )
        }
    }
}

// MARK: - Previews

private func previewDate(_ hour: Int, _ minute: Int = 0) -> Date {
    Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
}

private func previewArc(_ hour: Int, _ minute: Int = 0, states: DayArcView.States) -> some View {
    let date = previewDate(hour, minute)
    return DayArcView(hour: DayArcGeometry.hour(of: date), states: states, now: date)
        .padding(.horizontal)
}

#Preview("Before 06:00") {
    previewArc(5, 10, states: .init(question: .next, move: .later, retro: .later))
}

#Preview("Mid-morning, nothing done") {
    previewArc(10, 30, states: .init(question: .next, move: .later, retro: .later))
}

#Preview("Done, next, later") {
    previewArc(15, 45, states: .init(question: .done, move: .next, retro: .later))
}

#Preview("After 22:00") {
    previewArc(22, 40, states: .init(question: .done, move: .done, retro: .done))
}

#Preview("Narrow row") {
    let date = previewDate(20, 10)
    DayArcView(hour: DayArcGeometry.hour(of: date), states: .init(question: .done, move: .done, retro: .next), now: date)
        .frame(width: 260)
}

#Preview("Onboarding picture") {
    DayArcView(hour: 7, states: .init(question: .next, move: .later, retro: .later))
        .padding(.horizontal)
}

#Preview("Accessibility size") {
    previewArc(15, 45, states: .init(question: .done, move: .next, retro: .later))
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Light, done, next, later") {
    previewArc(15, 45, states: .init(question: .done, move: .next, retro: .later))
        .preferredColorScheme(.light)
}
