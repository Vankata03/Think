//
//  SilenceDistractionsView.swift
//  Think
//

import SwiftUI

/// The Focus-mode guide, pushed from Settings' Focus section. It moved out
/// of the Focus tab's toolbar (design-system section 13.3).
struct SilenceDistractionsView: View {
    var body: some View {
        List {
            Section {
                Text("Apps can't turn on a Focus for you — Apple keeps that under your control. Set it up once and your phone goes quiet automatically whenever you start a session here.")
            }

            Section("Create a Deep Work Focus") {
                step(1, "Open Settings, then Focus.")
                step(2, "Tap + and choose Custom. Name it Deep Work.")
                step(3, "Allow notifications only from people who genuinely need you.")
            }

            Section("Turn it on automatically") {
                step(1, "Open the Shortcuts app, then Automation.")
                step(2, "Tap +, choose App, pick Think, select Is Opened.")
                step(3, "Add the action Set Focus, choose Deep Work, and set Run Immediately.")
            }
        }
        .navigationTitle("Silence distractions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "\(number).circle")
        }
        .foregroundStyle(ThinkColor.label)
    }
}

#Preview {
    NavigationStack {
        SilenceDistractionsView()
    }
}
