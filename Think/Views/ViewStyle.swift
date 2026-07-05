//
//  ViewStyle.swift
//  Think
//

import SwiftUI

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
