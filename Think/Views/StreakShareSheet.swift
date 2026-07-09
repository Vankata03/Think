//
//  StreakShareSheet.swift
//  Think
//

import Photos
import SwiftUI

struct StreakShareSheet: View {
    let month: Date
    @Environment(ProgressStore.self) private var progress
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics

    @State private var kind: StreakCardKind = .streak
    @State private var style: CardStyle = .paper
    @State private var photoSaveState = PhotoSaveState.idle
    /// Rendered once per card-input combination; re-rendering the full
    /// 1080x1920 card on every body evaluation is wasteful. Keyed so a
    /// stale image is never shared while a re-render is in flight.
    @State private var renderedImage: (key: String, image: UIImage)?

    private let previewScale = 0.24
    private var prominentButtonForeground: Color {
        .prominentButtonForeground(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                cardPreview
                kindPicker
                stylePicker
                actions
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Share streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .task(id: renderKey) {
            renderedImage = (renderKey, renderUIImage())
        }
    }

    /// Everything the card draws from: card kind, theme, month, and the
    /// progress values baked into the image.
    private var renderKey: String {
        "\(kind.id)|\(style.id)|\(month.timeIntervalSinceReferenceDate)|\(progress.displayedStreak)|\(progress.completedDays.hashValue)"
    }

    private var currentRenderedImage: UIImage? {
        guard let renderedImage, renderedImage.key == renderKey else { return nil }
        return renderedImage.image
    }

    private var card: StreakCardView {
        StreakCardView(
            kind: kind,
            streak: progress.displayedStreak,
            month: month,
            completedDays: progress.completedDays,
            style: style
        )
    }

    /// Caption attached to the share so the image travels with a hook.
    private var shareMessage: String {
        let days = progress.displayedStreak
        let run = days == 1 ? "1 day" : "\(days) days"
        return "\(run) of deliberate thinking with Think — one honest question a day."
    }

    private var cardPreview: some View {
        card
            .scaleEffect(previewScale)
            .frame(
                width: StreakCardView.designSize.width * previewScale,
                height: StreakCardView.designSize.height * previewScale
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .animation(.default, value: style)
            .animation(.default, value: kind)
    }

    private var kindPicker: some View {
        Picker("Card", selection: $kind) {
            ForEach(StreakCardKind.allCases) { candidate in
                Text(candidate.name).tag(candidate)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .onChange(of: kind) {
            haptics.play(.selection)
            photoSaveState = .idle
        }
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
        let image = Image(uiImage: currentRenderedImage ?? UIImage())

        return HStack(spacing: 12) {
            ShareLink(
                item: image,
                message: Text(shareMessage),
                preview: SharePreview(shareMessage, image: image)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(prominentButtonForeground)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(currentRenderedImage == nil)
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

    private func renderUIImage() -> UIImage {
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(StreakCardView.designSize)
        renderer.scale = 1
        return renderer.uiImage ?? UIImage()
    }

    private func saveToPhotos() {
        photoSaveState = .saving
        let image = currentRenderedImage ?? renderUIImage()

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
    StreakShareSheet(month: .now)
        .environment(ProgressStore())
}
