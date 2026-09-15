import Foundation
import Observation

/// Optional local discovery preferences. Daily assignments remain shared and
/// unchanged; feedback is never sent to a server or treated as inferred use.
@MainActor @Observable
final class PracticePreferencesStore {
    enum Feedback: String, Codable { case tried, lessLikeThis }
    private let defaults: UserDefaults
    private static let preferenceKey = "practice.discovery.preference"
    private static let feedbackKey = "practice.discovery.feedback"
    private(set) var preference: PracticePreference
    private(set) var feedback: [String: Feedback]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preference = defaults.data(forKey: Self.preferenceKey)
            .flatMap { try? JSONDecoder().decode(PracticePreference.self, from: $0) } ?? PracticePreference()
        feedback = defaults.data(forKey: Self.feedbackKey)
            .flatMap { try? JSONDecoder().decode([String: Feedback].self, from: $0) } ?? [:]
    }

    func setPreference(_ value: PracticePreference) {
        preference = value
        defaults.set(try? JSONEncoder().encode(value), forKey: Self.preferenceKey)
    }

    func setFeedback(_ value: Feedback?, for practiceID: String) {
        feedback[practiceID] = value
        defaults.set(try? JSONEncoder().encode(feedback), forKey: Self.feedbackKey)
    }

    var suggestions: [DailyPractice] {
        ContentLibrary.suggestions(for: preference).filter { feedback[$0.id] != .lessLikeThis }
    }

    func reset() {
        preference = PracticePreference(); feedback = [:]
        defaults.removeObject(forKey: Self.preferenceKey)
        defaults.removeObject(forKey: Self.feedbackKey)
    }
}
