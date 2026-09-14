import SwiftUI
import UIKit

/// Covers every app window before an inactive/background snapshot, including
/// presented editors and export sheets. Authentication grace is a separate
/// policy: returning to the foreground removes the cover only after the app
/// has reevaluated its journal lock.
@MainActor
final class AppPrivacyShield: NSObject {
    private var covers: [UIWindow] = []

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cover),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cover),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    isolated deinit {
        NotificationCenter.default.removeObserver(self)
        covers.forEach { $0.isHidden = true }
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        if phase == .active {
            covers.forEach { $0.isHidden = true }
            covers.removeAll()
        } else {
            cover()
        }
    }

    @objc private func cover() {
        let coveredScenes = Set(covers.compactMap { $0.windowScene?.session.persistentIdentifier })
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            guard !coveredScenes.contains(scene.session.persistentIdentifier),
                  scene.activationState != .unattached else { continue }
            let controller = UIViewController()
            controller.view.backgroundColor = UIColor(red: 0.086, green: 0.086, blue: 0.094, alpha: 1)
            let icon = UIImageView(image: UIImage(named: "LaunchIcon"))
            icon.contentMode = .scaleAspectFit
            icon.layer.cornerRadius = 32
            icon.clipsToBounds = true
            icon.isAccessibilityElement = true
            icon.accessibilityLabel = "Think"
            icon.translatesAutoresizingMaskIntoConstraints = false
            controller.view.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 160),
                icon.heightAnchor.constraint(equalTo: icon.widthAnchor),
                icon.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
            ])
            controller.view.accessibilityViewIsModal = true
            controller.view.accessibilityIdentifier = "AppPrivacyShield"
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = controller
            // Do not take key-window status or interfere with system owner
            // authentication. This opaque app window covers app content only.
            window.isHidden = false
            covers.append(window)
        }
    }
}
