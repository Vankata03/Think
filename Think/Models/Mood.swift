//
//  Mood.swift
//  Think
//

import Foundation

/// One-tap emotional tag for a journal entry or an evening
/// retrospective.
///
/// Five fixed values rather than a numeric scale: the labels stay in the
/// app's plain, non-clinical register, and a small fixed set is what a
/// later trend view needs. Models store the raw value, so a value written
/// by a future version degrades to "untagged" instead of failing to load.
enum Mood: String, CaseIterable, Identifiable, Sendable {
    case low
    case flat
    case steady
    case good
    case sharp

    var id: String { rawValue }

    /// Maps a stored raw value, tolerating nil and anything unrecognised.
    init?(stored rawValue: String?) {
        guard let rawValue, let mood = Mood(rawValue: rawValue) else { return nil }
        self = mood
    }

    var label: String {
        switch self {
        case .low: String(localized: "Low")
        case .flat: String(localized: "Flat")
        case .steady: String(localized: "Steady")
        case .good: String(localized: "Good")
        case .sharp: String(localized: "Sharp")
        }
    }

    /// Stable English name for the plain-text export, whose headings
    /// ("JOURNAL ENTRIES", "Prompt:", "What went well:") are English in
    /// every locale. Using the localized label here would produce a
    /// mixed-language document.
    var exportLabel: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .low: "cloud.rain"
        case .flat: "cloud"
        case .steady: "cloud.sun"
        case .good: "sun.max"
        case .sharp: "bolt"
        }
    }
}
