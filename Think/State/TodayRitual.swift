//
//  TodayRitual.swift
//  Think
//

import Foundation

/// The ritual as Today shows it at one moment (`design/today.md` sections 2
/// to 4): which act the next-act panel offers, how the day arc draws each
/// marker, and which acts fill the section under the panel.
nonisolated struct TodayRitual: Equatable {
    /// The three acts, in ritual order.
    enum Act: CaseIterable, Hashable {
        case question, move, retro
    }

    /// What the next-act panel holds.
    enum Panel: Equatable {
        case act(Act)
        case complete
    }

    var answered: Bool
    var moveDone: Bool
    var retroWritten: Bool
    /// The hour of the day, 0 to 24, with minutes as the fraction.
    var hour: Double

    func isDone(_ act: Act) -> Bool {
        switch act {
        case .question: answered
        case .move: moveDone
        case .retro: retroWritten
        }
    }

    /// The retro act appears at 20:00; before that it is only the later row
    /// and the dashed marker (today.md section 2).
    static let retroOpeningHour = DayArcGeometry.markerHours[2]

    /// The first act not yet done, in ritual order, once it is open.
    var nextAct: Act? {
        guard let first = Act.allCases.first(where: { !isDone($0) }) else { return nil }
        if first == .retro && hour < Self.retroOpeningHour { return nil }
        return first
    }

    var isComplete: Bool { Act.allCases.allSatisfy(isDone) }

    var panel: Panel {
        nextAct.map(Panel.act) ?? .complete
    }

    var arcStates: DayArcView.States {
        DayArcView.States(question: state(of: .question), move: state(of: .move), retro: state(of: .retro))
    }

    /// The acts section under the panel: every act the panel is not
    /// showing, done or later, in ritual order.
    var otherActs: [Act] {
        Act.allCases.filter { $0 != nextAct }
    }

    private func state(of act: Act) -> StepDisc.State {
        if isDone(act) { return .done }
        return act == nextAct ? .next : .later
    }
}
