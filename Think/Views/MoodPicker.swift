//
//  MoodPicker.swift
//  Think
//

import SwiftUI

/// Optional one-tap mood tag. Tapping the selected chip clears it, so a
/// mis-tap is never sticky, and saving with no selection stays normal.
struct MoodPicker: View {
    @Binding var selection: Mood?

    @Environment(\.haptics) private var haptics
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How is it going?")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Mood.allCases) { mood in
                        chip(for: mood)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("MoodPicker")
    }

    private func chip(for mood: Mood) -> some View {
        let isSelected = selection == mood

        return Button {
            haptics.play(.selection)
            selection = isSelected ? nil : mood
        } label: {
            Label(mood.label, systemImage: mood.systemImage)
                .font(.subheadline)
                .foregroundStyle(isSelected ? Color.prominentButtonForeground(for: colorScheme) : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("Mood.\(mood.rawValue)")
    }
}

#Preview {
    @Previewable @State var selection: Mood?

    return MoodPicker(selection: $selection)
        .padding()
}
