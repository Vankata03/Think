//
//  AppearanceTiles.swift
//  Think
//

import SwiftUI

/// Dark, Auto and Light as pictures of Today (`onboarding.md` 5.1), in
/// onboarding and Settings. A tap writes the choice at once, so the screen
/// is its own preview. Side by side, stacked into rows at accessibility
/// sizes.
struct AppearanceTiles: View {
    @Binding var selection: Appearance
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let order: [Appearance] = [.dark, .system, .light]

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: ThinkSpacing.l))
            : AnyLayout(HStackLayout(alignment: .top, spacing: ThinkSpacing.s))
        layout {
            ForEach(Self.order) { option in
                tile(option, stacked: stacked)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ThinkSpacing.s)
    }

    private func tile(_ option: Appearance, stacked: Bool) -> some View {
        let selected = option == selection
        let parts = Group {
            AppearanceThumbnail(option: option)
                .frame(width: stacked ? 44 : 62, height: stacked ? 80 : 112)
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(selected ? ThinkColor.accent : .clear, lineWidth: 2.5)
                        .padding(-4)
                }
                .padding(4)
            Text(option.label)
                .font(.think(.secondary))
                .foregroundStyle(ThinkColor.label)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? ThinkColor.accent : ThinkColor.tertiaryLabel)
        }
        return Button {
            selection = option
        } label: {
            if stacked {
                HStack(spacing: ThinkSpacing.l) { parts }
            } else {
                VStack(spacing: ThinkSpacing.s) { parts }
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("Appearance.\(option.rawValue)")
    }
}

/// A miniature Today drawn in one scheme's fixed colours, split down the
/// middle for Auto, so it reads the same in either appearance.
private struct AppearanceThumbnail: View {
    var option: Appearance

    var body: some View {
        HStack(spacing: 0) {
            switch option {
            case .dark: pane(dark: true)
            case .light: pane(dark: false)
            case .system:
                pane(dark: true).frame(minWidth: 0, maxWidth: .infinity).clipped()
                pane(dark: false).frame(minWidth: 0, maxWidth: .infinity).clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.gray.opacity(0.35), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    /// The thumbnail is drawn in the fixed values of each scheme's tokens.
    private func pane(dark: Bool) -> some View {
        let background = dark ? Color.black : Color(red: 0.949, green: 0.949, blue: 0.969)
        let track = dark ? Color(white: 0.33) : Color(white: 0.78)
        let bar = dark ? Color(white: 0.23) : Color(white: 0.78)
        let card = dark ? Color(white: 0.11) : Color.white
        let accent = dark ? Color(red: 1, green: 0.831, blue: 0.2) : Color(red: 0.949, green: 0.769, blue: 0.11)  // style-exempt: the thumbnail draws both schemes at once
        return VStack(spacing: 5) {
            ZStack(alignment: .topLeading) {
                Circle().trim(from: 0.5, to: 1).stroke(track, lineWidth: 2).frame(width: 34, height: 34)
                Circle().fill(accent).frame(width: 6, height: 6).offset(x: 3, y: 5)
            }
            .frame(width: 34, height: 17, alignment: .top)
            .clipped()
            Capsule().fill(bar).frame(width: 40, height: 4)
            Capsule().fill(bar).frame(width: 30, height: 4)
            RoundedRectangle(cornerRadius: 6).fill(card).frame(width: 50, height: 22)
                .overlay(alignment: .bottom) {
                    Capsule().fill(accent).frame(width: 36, height: 6).padding(.bottom, 4)
                }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .frame(width: 62)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}
