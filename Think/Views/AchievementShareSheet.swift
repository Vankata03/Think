//
//  AchievementShareSheet.swift
//  Think
//

import Photos
import SwiftUI
import UIKit

struct AchievementShareSheet: View {
    let achievement: ProgressAchievement

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var style: CardStyle = .paper
    @State private var photoSaveState = PhotoSaveState.idle
    @State private var renderedImage: (key: String, image: UIImage)?

    private let previewScale = 0.24

    init(achievement: ProgressAchievement) {
        switch achievement {
        case .path, .focus:
            self.achievement = achievement
        case .streak:
            assertionFailure("Streak achievements must use StreakShareSheet")
            self.achievement = .path(achievement.target)
        }
    }

    private var prominentButtonForeground: Color {
        .prominentButtonForeground(for: colorScheme)
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
        .task(id: renderKey) {
            if let image = renderUIImage() {
                renderedImage = (renderKey, image)
            } else {
                renderedImage = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, photoSaveState == .denied else { return }
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .authorized || status == .limited {
                photoSaveState = .idle
            }
        }
    }

    private var renderKey: String {
        "\(achievement.id)|\(style.id)"
    }

    private var currentRenderedImage: UIImage? {
        guard let renderedImage, renderedImage.key == renderKey else { return nil }
        return renderedImage.image
    }

    private var card: AchievementCardView {
        AchievementCardView(achievement: achievement, style: style)
    }

    private var cardPreview: some View {
        card
            .scaleEffect(previewScale)
            .frame(
                width: AchievementCardView.designSize.width * previewScale,
                height: AchievementCardView.designSize.height * previewScale
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .animation(ThinkMotion.move, value: style)
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
                message: Text(achievement.shareMessage),
                preview: SharePreview(achievement.shareMessage, image: image)
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
        }
    }

    private func renderUIImage() -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(AchievementCardView.designSize)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func saveToPhotos() {
        photoSaveState = .saving
        guard let image = currentRenderedImage ?? renderUIImage() else {
            photoSaveState = .failed
            haptics.play(.warning)
            return
        }

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
    AchievementShareSheet(achievement: .focus(50))
}
