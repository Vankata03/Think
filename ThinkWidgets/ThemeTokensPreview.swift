//
//  ThemeTokensPreview.swift
//  ThinkWidgets
//
//  The extension compiles no asset catalog of its own besides the one in
//  ThinkShared/Design, so this preview is where `ThinkColor.accent` and
//  `accentInk` are seen to resolve from it (design-system section 10).
//

import SwiftUI

#if DEBUG
private struct ThemeTokenSwatches: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.s) {
            HStack(spacing: ThinkSpacing.s) {
                Image(systemName: ThinkSymbol.streak)
                    .foregroundStyle(ThinkColor.accentOnFill)
                    .padding(ThinkSpacing.s)
                    .background(ThinkColor.accent, in: Circle())
                Text(verbatim: "accent")
            }
            Label { Text(verbatim: "accentInk") } icon: { Image(systemName: ThinkSymbol.dailyLine) }
                .foregroundStyle(ThinkColor.accentInk)
            Text(verbatim: "12")
                .font(.think(.numeral))
        }
        .padding(ThinkSpacing.l)
        .background(ThinkColor.surface)
    }
}

#Preview("Theme tokens, dark") {
    ThemeTokenSwatches()
        .preferredColorScheme(.dark)
}

#Preview("Theme tokens, light") {
    ThemeTokenSwatches()
        .preferredColorScheme(.light)
}
#endif
