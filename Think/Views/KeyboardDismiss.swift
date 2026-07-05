//
//  KeyboardDismiss.swift
//  Think
//

import SwiftUI
import UIKit

extension View {
    /// Dismisses the keyboard when the user taps outside a focused
    /// input. Runs alongside other gestures, so buttons keep working.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
        })
    }
}
