//
//  ShareCardSheet.swift
//  Think
//

import Photos
import SwiftUI
import UIKit

struct ShareCardSheet: View {
    let quote: Quote
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FavoritesStore.self) private var favorites

    @State private var style: CardStyle = .paper
    @State private var photoSaveState = PhotoSaveState.idle

    private let previewScale = 0.24
    private var prominentButtonForeground: Color {
        .prominentButtonForeground(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                cardPreview
                stylePicker
                actions
                favoriteButton
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Share card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("DismissShareCard")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ShareCardSheet")
        }
        .presentationDetents([.large])
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, photoSaveState == .denied else { return }
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .authorized || status == .limited {
                photoSaveState = .idle
            }
        }
    }

    private var cardPreview: some View {
        QuoteCardView(quote: quote, style: style)
            .scaleEffect(previewScale)
            .frame(
                width: QuoteCardView.designSize.width * previewScale,
                height: QuoteCardView.designSize.height * previewScale
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .animation(.default, value: style)
    }

    private var stylePicker: some View {
        HStack(spacing: 12) {
            ForEach(CardStyle.all) { candidate in
                Button {
                    if candidate != style {
                        haptics.play(.selection)
                        style = candidate
                        photoSaveState = .idle
                    }
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(candidate.background)
                            .strokeBorder(.separator, lineWidth: 0.5)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if candidate == style {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(candidate.text)
                                }
                            }
                        Text(candidate.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("CardStyle.\(candidate.id)")
            }
        }
    }

    private var actions: some View {
        let image = renderedImage()

        return HStack(spacing: 12) {
            ShareLink(
                item: image,
                preview: SharePreview(quote.text, image: image)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(prominentButtonForeground)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .foregroundStyle(prominentButtonForeground)
            .simultaneousGesture(TapGesture().onEnded {
                haptics.play(.selection)
            })

            Button {
                if photoSaveState == .denied {
                    openAppSettings()
                } else {
                    saveToPhotos()
                }
            } label: {
                Label(photoSaveState.label, systemImage: photoSaveState.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(photoSaveState == .saving || photoSaveState == .saved)
            .accessibilityIdentifier("SaveShareCard")
        }
    }

    /// A line is often worth keeping exactly when it is worth sharing, so
    /// the affordance sits where that thought happens.
    private var favoriteButton: some View {
        let isFavorite = favorites.isFavorite(quote)

        return Button {
            haptics.play(.selection)
            favorites.toggle(quote)
        } label: {
            Label(
                isFavorite
                    ? String(localized: "Saved to your lines")
                    : String(localized: "Save this line"),
                systemImage: isFavorite ? "heart.fill" : "heart"
            )
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.plain)
        .tint(.accentColor)
        .foregroundStyle(Color.accentColor)
        .accessibilityIdentifier("FavoriteFromShareCard")
    }

    private func renderedImage() -> Image {
        Image(uiImage: renderUIImage())
    }

    private func renderUIImage() -> UIImage {
        let renderer = ImageRenderer(content: QuoteCardView(quote: quote, style: style))
        renderer.proposedSize = ProposedViewSize(QuoteCardView.designSize)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage ?? UIImage()
    }

    private func saveToPhotos() {
        photoSaveState = .saving
        let image = renderUIImage()

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    photoSaveState = .denied
                    haptics.play(.warning)
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                Task { @MainActor in
                    photoSaveState = success ? .saved : .failed
                    haptics.play(success ? .success : .warning)
                }
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    ShareCardSheet(quote: ContentLibrary.dailyQuote())
        .environment(FavoritesStore(defaults: .standard))
}
