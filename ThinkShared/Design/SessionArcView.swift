//
//  SessionArcView.swift
//  ThinkShared
//

import SwiftUI

/// Where everything on the Focus session arc sits (focus.md section 3). The
/// session is the upper half of a circle: the work part from the left end,
/// then the break tail to the right end, in proportion to their minutes.
nonisolated struct SessionArcGeometry: Equatable {
    /// The part of the session the sun is in.
    enum Stage: Equatable {
        case idle
        case work
        case rest
    }

    static let maxRadius: CGFloat = 136
    static let strokeWidth: CGFloat = 3
    static let sunDiameter: CGFloat = 24
    static let haloDiameter: CGFloat = 44
    static let boundaryDotDiameter: CGFloat = 8
    /// Room above the curve for the sun's halo and an outside caption.
    static let topInset: CGFloat = 44
    /// Room below the arc ends for the "now" and end-of-break captions.
    static let bottomInset: CGFloat = 46
    /// The arc ends' captions sit this far below the ends.
    static let endLabelDrop: CGFloat = 32
    /// The end-of-work caption sits this far off the curve.
    static let captionOffset: CGFloat = 32
    /// The gap either side of the work/break boundary, in points of curve.
    static let boundaryGap: CGFloat = 6
    /// The centre text's centre sits this far above the circle's centre.
    static let centreTextRise: CGFloat = 46

    var width: CGFloat

    /// The diameter is the content width minus 60pt, capped.
    var radius: CGFloat { max(0, min((width - 60) / 2, Self.maxRadius)) }
    var rowHeight: CGFloat { Self.topInset + radius + Self.bottomInset }
    var center: CGPoint { CGPoint(x: width / 2, y: radius + Self.topInset) }

    /// The work part of the curve: `work / (work + break)`.
    static func workShare(workMinutes: Int, breakMinutes: Int) -> Double {
        let total = max(workMinutes, 0) + max(breakMinutes, 0)
        guard total > 0 else { return 1 }
        return Double(max(workMinutes, 0)) / Double(total)
    }

    /// The sun sits at now: at the left end while idle, moving through the
    /// work part during work, then along the tail during the break.
    static func sunFraction(stage: Stage, phaseProgress: Double, workShare: Double) -> Double {
        let progress = min(max(phaseProgress, 0), 1)
        switch stage {
        case .idle: return 0
        case .work: return progress * workShare
        case .rest: return workShare + progress * (1 - workShare)
        }
    }

    func point(at fraction: Double) -> CGPoint {
        ArcPosition.point(fraction: fraction, center: center, radius: radius)
    }

    /// Half the boundary gap, as a fraction of the curve.
    var halfGapFraction: Double {
        guard radius > 0 else { return 0 }
        return Double(Self.boundaryGap / 2 / (.pi * radius))
    }

    /// Where the end-of-work caption is centred: outside the curve at the
    /// boundary. Past about 80% of the curve (focus.md section 12) it would
    /// run off the trailing edge, so it moves in to stay within the row and
    /// climbs along the same outer circle, which keeps it clear of the
    /// stroke. Inside the curve it would sit on the countdown.
    func endCaptionCentre(workShare: Double, captionWidth: CGFloat) -> CGPoint {
        let outer = radius + Self.captionOffset
        let point = ArcPosition.point(fraction: workShare, center: center, radius: outer)
        let x = DayArcGeometry.clampedCentre(point.x, width: captionWidth, within: width)
        guard x != point.x else { return point }
        let dx = min(abs(x - center.x), outer)
        return CGPoint(x: x, y: center.y - (outer * outer - dx * dx).squareRoot())
    }
}

/// The Focus session drawn as a half circle in the style of the day arc:
/// work and break share one curve, the sun marks now, and the countdown sits
/// in the centre (focus.md section 3). At accessibility sizes it yields to the
/// countdown over a bar (design-system 13.7).
struct SessionArcView: View {
    var workMinutes: Int
    var breakMinutes: Int
    var stage: SessionArcGeometry.Stage
    var isPaused: Bool
    /// How far through the current phase, 0 to 1.
    var phaseProgress: Double
    /// The countdown as the timer shows it ("24:13").
    var countdown: String
    var workEnd: Date
    var breakEnd: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var width = CGFloat.infinity
    @State private var endCaptionWidth: CGFloat = 0
    @ThinkSpacing.Scaled(ThinkSpacing.s) private var linearSpacing

    private var workShare: Double {
        SessionArcGeometry.workShare(workMinutes: workMinutes, breakMinutes: breakMinutes)
    }

    private var sunFraction: Double {
        SessionArcGeometry.sunFraction(stage: stage, phaseProgress: phaseProgress, workShare: workShare)
    }

    private var sunAnimation: Animation? { ThinkMotion.glide(reduceMotion: reduceMotion) }
    private var proportionAnimation: Animation? { ThinkMotion.proportion(reduceMotion: reduceMotion) }

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
            let geometry = SessionArcGeometry(width: proxy.size.width)
            let center = geometry.center
            let radius = geometry.radius
            let gap = geometry.halfGapFraction
            ZStack {
                segment(0, workShare - gap, geometry)
                    .stroke(ThinkColor.separator, style: stroke())
                segment(workShare + gap, 1, geometry)
                    .stroke(
                        ThinkColor.success.opacity(0.45),
                        style: stroke(dashed: stage == .idle))
                if stage != .idle {
                    segment(0, min(sunFraction, workShare - gap), geometry)
                        .stroke(ThinkColor.accent, style: stroke())
                }
                if stage == .rest, sunFraction > workShare + gap {
                    segment(workShare + gap, sunFraction, geometry)
                        .stroke(ThinkColor.success, style: stroke())
                }
                Circle()
                    .fill(ThinkColor.background)
                    .overlay(Circle().stroke(ThinkColor.success, lineWidth: 1.5))
                    .frame(
                        width: SessionArcGeometry.boundaryDotDiameter,
                        height: SessionArcGeometry.boundaryDotDiameter
                    )
                    .arcPosition(workShare, center: center, radius: radius)
                sun
                    .arcPosition(sunFraction, center: center, radius: radius)
                    .animation(sunAnimation, value: sunFraction)
                endOfWorkCaption
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { endCaptionWidth = $0 })
                    .position(geometry.endCaptionCentre(workShare: workShare, captionWidth: endCaptionWidth))
                centreText
                    .position(x: center.x, y: center.y - SessionArcGeometry.centreTextRise)
                if stage == .idle {
                    endLabel(
                        Text(LocalizedStringResource("now", table: "Design")), color: ThinkColor.secondaryLabel,
                        x: center.x - radius, y: center.y + SessionArcGeometry.endLabelDrop)
                }
                endLabel(
                    Text(breakEnd, format: .dateTime.hour().minute()), color: ThinkColor.success,
                    x: center.x + radius, y: center.y + SessionArcGeometry.endLabelDrop)
            }
            .animation(proportionAnimation, value: workShare)
        }
        .frame(height: SessionArcGeometry(width: width).rowHeight)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width = $0 })
    }

    private func stroke(dashed: Bool = false) -> StrokeStyle {
        StrokeStyle(lineWidth: SessionArcGeometry.strokeWidth, lineCap: .round, dash: dashed ? [4, 5] : [])
    }

    private func segment(_ from: Double, _ to: Double, _ geometry: SessionArcGeometry) -> some Shape {
        let start = min(max(from, 0), 1)
        let end = min(max(to, start), 1)
        return Circle()
            .trim(from: 0.5 + start / 2, to: 0.5 + end / 2)
            .size(width: geometry.radius * 2, height: geometry.radius * 2)
            .offset(x: geometry.center.x - geometry.radius, y: geometry.center.y - geometry.radius)
    }

    private var sun: some View {
        let color = stage == .rest ? ThinkColor.success : ThinkColor.accent
        return ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: SessionArcGeometry.haloDiameter, height: SessionArcGeometry.haloDiameter)
            Circle()
                .fill(color)
                .frame(width: SessionArcGeometry.sunDiameter, height: SessionArcGeometry.sunDiameter)
        }
    }

    private var endOfWorkCaption: some View {
        Group {
            if stage == .rest {
                Text(LocalizedStringResource("done", table: "Design"))
            } else {
                Text(workEnd, format: .dateTime.hour().minute())
            }
        }
        .font(.think(.graphicCaption))
        .foregroundStyle(ThinkColor.accentInk)
        .fixedSize()
    }

    private func endLabel(_ text: Text, color: Color, x: CGFloat, y: CGFloat) -> some View {
        text
            .font(.think(.graphicCaption))
            .foregroundStyle(color)
            .fixedSize()
            .modifier(CentredInRow(point: CGPoint(x: x, y: y)))
    }

    private var centreText: some View {
        VStack(spacing: ThinkSpacing.xs) {
            countdownText
            phaseCaption
        }
        .fixedSize()
    }

    private var countdownText: some View {
        Text(countdown)
            .thinkCountdownFont()
            .foregroundStyle(ThinkColor.label)
    }

    /// "then *n* min break" while idle, "until *time*" while running,
    /// "Paused", or "Break".
    private var phaseCaption: some View {
        Group {
            switch stage {
            case .idle:
                let breakText = Text(LocalizedStringResource("\(breakMinutes) min break", table: "Design"))
                    .foregroundStyle(ThinkColor.success)
                Text("then \(breakText)", tableName: "Design")
            case .work where isPaused:
                Text(LocalizedStringResource("Paused", table: "Design"))
            case .work:
                Text(LocalizedStringResource("until \(workEnd.formatted(.dateTime.hour().minute()))", table: "Design"))
            case .rest:
                Text(LocalizedStringResource("Break", table: "Design"))
                    .foregroundStyle(ThinkColor.success)
            }
        }
        .font(.think(.secondary))
        .foregroundStyle(ThinkColor.secondaryLabel)
        .multilineTextAlignment(.center)
    }

    // MARK: Accessibility sizes

    /// The countdown, the caption and a bar, with the phase's end time under
    /// the bar's trailing end.
    private var linearForm: some View {
        VStack(spacing: linearSpacing) {
            countdownText
            phaseCaption
            ProgressView(value: stage == .idle ? 0 : min(max(phaseProgress, 0), 1))
                .tint(stage == .rest ? ThinkColor.success : ThinkColor.accent)
                .animation(sunAnimation, value: phaseProgress)
            Text(phaseEnd, format: .dateTime.hour().minute())
                .font(.think(.graphicCaption))
                .foregroundStyle(stage == .rest ? ThinkColor.success : ThinkColor.accentInk)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private var phaseEnd: Date { stage == .rest ? breakEnd : workEnd }

    private var accessibilityLabel: Text {
        let end = phaseEnd.formatted(.dateTime.hour().minute())
        switch stage {
        case .idle:
            return Text(
                LocalizedStringResource(
                    "\(countdown) of deep work, then \(breakMinutes) min break. Ends at \(end).", table: "Design"))
        case .work where isPaused:
            return Text(LocalizedStringResource("\(countdown) left. Deep work, paused.", table: "Design"))
        case .work:
            return Text(LocalizedStringResource("\(countdown) left. Deep work until \(end).", table: "Design"))
        case .rest:
            return Text(LocalizedStringResource("\(countdown) left. Break until \(end).", table: "Design"))
        }
    }
}

/// Centres text on a point like `.position`, but keeps it inside the row.
private struct CentredInRow: ViewModifier {
    var point: CGPoint

    func body(content: Content) -> some View {
        CentredInRowLayout(point: point) { content }
    }
}

private struct CentredInRowLayout: Layout {
    var point: CGPoint

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let x = DayArcGeometry.clampedCentre(point.x, width: size.width, within: bounds.width)
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + point.y),
                anchor: .center,
                proposal: ProposedViewSize(size)
            )
        }
    }
}

// MARK: - Previews

private func previewArc(
    _ work: Int, _ rest: Int, stage: SessionArcGeometry.Stage, paused: Bool = false,
    progress: Double = 0, countdown: String
) -> some View {
    let now = Date.now
    return SessionArcView(
        workMinutes: work, breakMinutes: rest, stage: stage, isPaused: paused, phaseProgress: progress,
        countdown: countdown,
        workEnd: now.addingTimeInterval(Double(work * 60) * (1 - progress)),
        breakEnd: now.addingTimeInterval(Double((work + rest) * 60))
    )
    .padding(.horizontal)
}

#Preview("Idle 25/5") { previewArc(25, 5, stage: .idle, countdown: "25:00") }
#Preview("Idle 50/10") { previewArc(50, 10, stage: .idle, countdown: "50:00") }
#Preview("Idle 30/15") { previewArc(30, 15, stage: .idle, countdown: "30:00") }
#Preview("Running") { previewArc(25, 5, stage: .work, progress: 0.4, countdown: "15:00") }
#Preview("Paused") { previewArc(25, 5, stage: .work, paused: true, progress: 0.4, countdown: "15:00") }
#Preview("Break") { previewArc(25, 5, stage: .rest, progress: 0.5, countdown: "02:30") }
#Preview("Light, running") {
    previewArc(25, 5, stage: .work, progress: 0.4, countdown: "15:00").preferredColorScheme(.light)
}
#Preview("Accessibility size") {
    previewArc(25, 5, stage: .work, progress: 0.4, countdown: "15:00")
        .environment(\.dynamicTypeSize, .accessibility3)
}
