//
//  FavoritesView.swift
//  Think
//

import SwiftUI

struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.haptics) private var haptics

    @State private var sharedQuote: Quote?

    var body: some View {
        List {
            if favorites.isEmpty {
                Text("Lines you keep will appear here.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("FavoritesEmpty")
            } else {
                ForEach(favorites.favorites) { quote in
                    Button {
                        haptics.play(.selection)
                        sharedQuote = quote
                    } label: {
                        row(quote)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            haptics.play(.selection)
                            favorites.remove(quote)
                        } label: {
                            Label("Remove", systemImage: "heart.slash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved lines")
        .accessibilityIdentifier("FavoritesView")
        .sheet(item: $sharedQuote) { quote in
            ShareCardSheet(quote: quote)
        }
    }

    private func row(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(quote.text)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let attribution = quote.attribution {
                Text(attribution)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
    }
    .environment(FavoritesStore(defaults: .standard))
}
