//
//  ViewStyle.swift
//  Think
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
}

extension Color {
    /// Label color for bordered-prominent accent buttons: the yellow
    /// accent needs a black label in dark mode, white in light.
    static func prominentButtonForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }
}

extension Binding where Value == Int {
    /// Bridges minutes-since-midnight storage to a `DatePicker` date.
    var timeOfDay: Binding<Date> {
        Binding<Date> {
            Calendar.current.date(
                bySettingHour: wrappedValue / 60,
                minute: wrappedValue % 60,
                second: 0, of: .now
            ) ?? .now
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }
}
