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
        case .idle: "Save"
        case .saving: "Saving"
        case .saved: "Saved"
        case .failed: "Retry"
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
