//
//  SettingsLinks.swift
//  Think
//

import Foundation

/// Where the Feedback and About rows in Settings lead.
enum SettingsLinks {
    static let feedbackAddress = "ivanterziev93@gmail.com"
    static let privacyPolicyURL = URL(string: "https://thinkapp.tech/privacy.html")!
    static let supportURL = URL(string: "https://thinkapp.tech/support.html")!

    /// A mail draft whose body carries the app and system versions, so a
    /// report arrives with the context needed to act on it.
    static func feedbackMail(subject: String, appVersion: String, systemVersion: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n—\nThink \(appVersion), iOS \(systemVersion)"),
        ]
        return components.url
    }

    static func versionText(info: [String: Any]?) -> String {
        guard let version = info?["CFBundleShortVersionString"] as? String else { return "?" }
        guard let build = info?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }

    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}
