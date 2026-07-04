//
//  ShareCardSheet.swift
//  Think
//

import Photos
import SwiftUI

private enum PhotoSaveState: Equatable {
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

struct ShareCardSheet: View {
    let quote: Quote
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics

    @State private var style: CardStyle = .paper
    @State private var photoSaveState = PhotoSaveState.idle

    private let previewScale = 0.24
    private var prominentButtonForeground: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                cardPreview
                stylePicker
                actions
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Share card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
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
                saveToPhotos()
            } label: {
                Label(photoSaveState.label, systemImage: photoSaveState.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(photoSaveState == .saving || photoSaveState == .saved)
        }
    }

    private func renderedImage() -> Image {
        Image(uiImage: renderUIImage())
    }

    private func renderUIImage() -> UIImage {
        let renderer = ImageRenderer(content: QuoteCardView(quote: quote, style: style))
        renderer.proposedSize = ProposedViewSize(QuoteCardView.designSize)
        renderer.scale = 1
        return renderer.uiImage ?? UIImage()
    }

    private func saveToPhotos() {
        photoSaveState = .saving
        let image = renderUIImage()

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    photoSaveState = .failed
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
}

#Preview {
    ShareCardSheet(quote: ContentLibrary.dailyQuote())
}
