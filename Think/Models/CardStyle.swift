//
//  CardStyle.swift
//  Think
//

import SwiftUI

/// Visual template for rendered quote cards and wallpapers.
/// `isPro` is informational until the paywall ships.
struct CardStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let background: Color
    let text: Color
    let accent: Color
    let isPro: Bool

    static let paper = CardStyle(
        id: "paper", name: "Paper",
        background: Color(red: 0.96, green: 0.95, blue: 0.91),
        text: Color(red: 0.13, green: 0.12, blue: 0.11),
        accent: Color(red: 0.45, green: 0.42, blue: 0.38),
        isPro: false
    )

    static let midnight = CardStyle(
        id: "midnight", name: "Midnight",
        background: Color(red: 0.07, green: 0.07, blue: 0.09),
        text: Color(red: 0.93, green: 0.92, blue: 0.89),
        accent: Color(red: 0.62, green: 0.61, blue: 0.58),
        isPro: false
    )

    static let clay = CardStyle(
        id: "clay", name: "Clay",
        background: Color(red: 0.76, green: 0.42, blue: 0.31),
        text: Color(red: 0.98, green: 0.95, blue: 0.91),
        accent: Color(red: 0.93, green: 0.82, blue: 0.74),
        isPro: true
    )

    static let forest = CardStyle(
        id: "forest", name: "Forest",
        background: Color(red: 0.09, green: 0.23, blue: 0.18),
        text: Color(red: 0.94, green: 0.94, blue: 0.88),
        accent: Color(red: 0.62, green: 0.72, blue: 0.63),
        isPro: true
    )

    static let all: [CardStyle] = [.paper, .midnight, .clay, .forest]
}
