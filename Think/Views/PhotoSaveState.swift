//
//  PhotoSaveState.swift
//  Think
//

import Foundation

/// Button state for the save-to-Photos action on share sheets.
enum PhotoSaveState: Equatable {
    case idle
    case saving
    case saved
    case failed

    var label: String {
        switch self {
        case .idle: String(localized: "Save")
        case .saving: String(localized: "Saving")
        case .saved: String(localized: "Saved")
        case .failed: String(localized: "Retry")
        }
    }

    var systemImage: String {
        switch self {
        case .idle, .failed: "square.and.arrow.down"
        case .saving: "hourglass"
        case .saved: "checkmark"
        }
    }
}
