//
//  AppReviewRequester.swift
//  Think
//

import StoreKit
import UIKit

@MainActor
enum AppReviewRequester {
    static func request() async {
        // Let the initiating button or achievement transition finish before
        // StoreKit presents from the app's foreground window.
        await Task.yield()

        let foregroundScenes = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .filter { $0.activationState == .foregroundActive }

        guard let windowScene = foregroundScenes.first(where: { scene in
            scene.windows.contains(where: \.isKeyWindow)
        }) ?? foregroundScenes.first
        else { return }

        AppStore.requestReview(in: windowScene)
    }
}
