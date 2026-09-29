//
//  Theme.swift
//  Think
//

import Foundation

/// What a journal record is about: one of eight fixed life areas.
///
/// A fixed set rather than open labels, so every theme can be localised,
/// filtered and counted across weeks. Themes are words, not symbols. Models
/// store the raw value, so a value written by a future version degrades to
/// "untagged" instead of failing to load. Weekly-review entries never carry
/// a theme; they summarise the week rather than being part of it.
nonisolated enum Theme: String, CaseIterable, Identifiable, Sendable {
    case work
    case people
    case health
    case money
    case learning
    case making
    case home
    case rest

    var id: String { rawValue }

    /// Maps a stored raw value, tolerating nil and anything unrecognised.
    init?(stored rawValue: String?) {
        guard let rawValue, let theme = Theme(rawValue: rawValue) else { return nil }
        self = theme
    }

    var label: String {
        switch self {
        case .work: String(localized: "Work")
        case .people: String(localized: "People")
        case .health: String(localized: "Health")
        case .money: String(localized: "Money")
        case .learning: String(localized: "Learning")
        case .making: String(localized: "Making")
        case .home: String(localized: "Home")
        case .rest: String(localized: "Rest")
        }
    }

    /// Stable English name for the plain-text export, which is English in
    /// every locale (see `Mood.exportLabel`).
    var exportLabel: String {
        rawValue.capitalized
    }
}

/// The up-to-two themes on one record, ordered primary then secondary.
///
/// Holds the selection rules the editor's Theme chip follows: a pick fills
/// the primary, then the secondary; a third pick replaces the secondary;
/// picking a chosen theme clears it; clearing the primary promotes the
/// secondary. A secondary never exists without a primary.
nonisolated struct ThemeSelection: Equatable, Sendable {
    private(set) var primary: Theme?
    private(set) var secondary: Theme?

    init(primary: Theme? = nil, secondary: Theme? = nil) {
        self.primary = primary ?? secondary
        self.secondary = primary == nil || secondary == primary ? nil : secondary
    }

    /// Reads the two stored raw values. An unrecognised primary lets a
    /// recognised secondary move up, so what reads back is always valid.
    init(stored primary: String?, secondary: String?) {
        self.init(primary: Theme(stored: primary), secondary: Theme(stored: secondary))
    }

    var themes: [Theme] { [primary, secondary].compactMap { $0 } }
    var isEmpty: Bool { primary == nil }

    func contains(_ theme: Theme) -> Bool { primary == theme || secondary == theme }

    mutating func toggle(_ theme: Theme) {
        if primary == theme {
            primary = secondary; secondary = nil
        } else if secondary == theme {
            secondary = nil
        } else if primary == nil {
            primary = theme
        } else {
            secondary = theme
        }
    }

    mutating func clear() {
        primary = nil; secondary = nil
    }
}
