//
//  QuoteCardView.swift
//  Think
//

import SwiftUI

/// The share-card / wallpaper design. Laid out in a fixed 1080x1920
/// design space; render it at that size with ImageRenderer, or scale
/// it down for previews.
struct QuoteCardView: View {
    let quote: Quote
    let style: CardStyle

    static let designSize = CGSize(width: 1080, height: 1920)

    var body: some View {
        ZStack {
            style.background

            VStack(spacing: 48) {
                Spacer()

                Rectangle()
                    .fill(style.accent)
                    .frame(width: 120, height: 6)

                Text(quote.text)
                    .font(.system(size: 72, weight: .medium, design: .serif))
                    .foregroundStyle(style.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(18)
                    .minimumScaleFactor(0.6)

                Text(quote.author)
                    .font(.system(size: 40, design: .serif))
                    .italic()
                    .foregroundStyle(style.accent)

                Spacer()

                Text("THINK")
                    .font(.system(size: 32, weight: .medium))
                    .kerning(14)
                    .foregroundStyle(style.accent)
                    .padding(.bottom, 120)
            }
            .padding(.horizontal, 120)
        }
        .frame(width: Self.designSize.width, height: Self.designSize.height)
    }
}

#Preview {
    QuoteCardView(quote: ContentLibrary.dailyQuote(), style: .paper)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}
