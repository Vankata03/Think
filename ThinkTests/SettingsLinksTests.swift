//
//  SettingsLinksTests.swift
//  ThinkTests
//

import Foundation
import Testing

@testable import Think

/// Feedback and About rows keep the mail subjects, version context and
/// links they had before the Settings Form (`progress-settings.md` section 3).
struct SettingsLinksTests {

    @Test func feedbackMailGoesToTheSupportAddressWithSubjectAndVersionContext() throws {
        let url = try #require(SettingsLinks.feedbackMail(subject: "Think — idea", appVersion: "1.1.1", systemVersion: "26.0"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(components.scheme == "mailto")
        #expect(components.path == "ivanterziev93@gmail.com")
        #expect(query["subject"] == "Think — idea")
        #expect(query["body"] == "\n\n—\nThink 1.1.1, iOS 26.0")
    }

    @Test func aboutShowsTheInstalledVersionAndBuild() {
        #expect(SettingsLinks.versionText(info: ["CFBundleShortVersionString": "1.1.1", "CFBundleVersion": "42"]) == "1.1.1 (42)")
        #expect(SettingsLinks.versionText(info: ["CFBundleShortVersionString": "1.1.1"]) == "1.1.1")
        #expect(SettingsLinks.versionText(info: nil) == "?")
    }

    @Test func supportAndPrivacyPointAtTheWebsite() {
        #expect(SettingsLinks.supportURL.absoluteString == "https://thinkapp.tech/support.html")
        #expect(SettingsLinks.privacyPolicyURL.absoluteString == "https://thinkapp.tech/privacy.html")
    }
}
