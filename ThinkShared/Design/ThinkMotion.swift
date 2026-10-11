//
//  ThinkMotion.swift
//  ThinkShared
//

import SwiftUI

enum ThinkMotion {
    static let enter = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
    static let move = Animation.timingCurve(0.77, 0, 0.175, 1, duration: 0.22)
    static let reduced = Animation.easeOut(duration: 0.2)

    static func stateAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : enter
    }

    static func stateTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.97).combined(with: .opacity)
    }

    /// A graphic gliding to a new value, such as the sun along an arc.
    /// Reduce Motion cuts (nil).
    static func glide(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.8)
    }

    /// A graphic's proportions changing, such as the work and break split.
    /// Reduce Motion cuts (nil).
    static func proportion(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.3)
    }
}
