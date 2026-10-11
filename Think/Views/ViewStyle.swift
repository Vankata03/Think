//
//  ViewStyle.swift
//  Think
//

import SwiftUI

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

extension View {
    /// Starts the row's separator at the row's leading content margin
    /// instead of at its label text, so every separator in a grouped list
    /// is inset the same on both sides, whatever icon or centred content
    /// the row holds.
    func fullWidthRowSeparator() -> some View {
        alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }
}
