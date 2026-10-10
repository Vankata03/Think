//
//  SavedLinesView.swift
//  Think
//

import SwiftUI

/// The lines the person kept, pushed from Today's bookmark
/// (`design/today.md` section 4). Just the lines: a row opens nothing.
/// Swipe to remove; long-press for Share and Remove.
struct SavedLinesView: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.haptics) private var haptics
    @State private var sharedQuote: Quote?
    @ThinkSpacing.Scaled(ThinkSpacing.xs) private var lineSpacing

    var body: some View {
        List {
            ForEach(favorites.favorites) { quote in
                row(quote)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if favorites.isEmpty {
                ContentUnavailableView {
                    Label("Lines you keep appear here.", systemImage: ThinkSymbol.dailyLine)
                }
                .accessibilityIdentifier("SavedLinesEmpty")
            }
        }
        .navigationTitle("Saved lines")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("SavedLines")
        .sheet(item: $sharedQuote) { quote in
            ShareCardSheet(quote: quote)
        }
    }

    private func row(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            Text(quote.text)
                .font(.think(.line))
                .foregroundStyle(ThinkColor.label)
                .fixedSize(horizontal: false, vertical: true)
            if let attribution = quote.attribution {
                Text(attribution)
                    .font(.think(.caption))
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
        }
        .padding(.vertical, ThinkSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("SavedLine.\(quote.id)")
        .swipeActions(edge: .trailing) {
            Button("Remove", systemImage: "\(ThinkSymbol.savedLine).slash", role: .destructive) {
                remove(quote)
            }
        }
        .contextMenu {
            Button("Share", systemImage: ThinkSymbol.share) {
                sharedQuote = quote
            }
            Button("Remove", systemImage: "\(ThinkSymbol.savedLine).slash", role: .destructive) {
                remove(quote)
            }
        }
    }

    private func remove(_ quote: Quote) {
        haptics.play(.selection)
        withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
            favorites.remove(quote)
        }
    }
}

#Preview {
    NavigationStack {
        SavedLinesView()
    }
    .environment(FavoritesStore(defaults: .standard))
}
