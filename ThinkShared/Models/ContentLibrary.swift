//
//  ContentLibrary.swift
//  Think
//

import Foundation

// Codable so the same models can be fed from a remote content
// endpoint later without touching call sites. Nonisolated because the
// widget extension reads quotes from timeline code off the main actor.
nonisolated struct Quote: Identifiable, Codable, Hashable {
    let text: String
    let author: String

    var id: String { text }
}

nonisolated enum ContentLibrary {

    // Public-domain sources (Stoics, proverbs) plus original lines only —
    // modern-author quotes are a licensing risk (see PLAN.md).
    static let quotes: [Quote] = [
        Quote(text: "You have power over your mind — not outside events. Realize this, and you will find strength.", author: "Marcus Aurelius"),
        Quote(text: "We suffer more often in imagination than in reality.", author: "Seneca"),
        Quote(text: "No man is free who is not master of himself.", author: "Epictetus"),
        Quote(text: "Waste no more time arguing about what a good man should be. Be one.", author: "Marcus Aurelius"),
        Quote(text: "Luck is what happens when preparation meets opportunity.", author: "Seneca"),
        Quote(text: "First say to yourself what you would be; and then do what you have to do.", author: "Epictetus"),
        Quote(text: "The impediment to action advances action. What stands in the way becomes the way.", author: "Marcus Aurelius"),
        Quote(text: "It is not that we have a short time to live, but that we waste a lot of it.", author: "Seneca"),
        Quote(text: "Confine yourself to the present.", author: "Marcus Aurelius"),
        Quote(text: "Difficulties strengthen the mind, as labor does the body.", author: "Seneca"),
        Quote(text: "Man conquers the world by conquering himself.", author: "Zeno of Citium"),
        Quote(text: "How long are you going to wait before you demand the best for yourself?", author: "Epictetus"),
        Quote(text: "If it is not right, do not do it; if it is not true, do not say it.", author: "Marcus Aurelius"),
        Quote(text: "While we wait for life, life passes.", author: "Seneca"),
        Quote(text: "Wealth consists not in having great possessions, but in having few wants.", author: "Epictetus"),
        Quote(text: "The best revenge is to be unlike him who performed the injury.", author: "Marcus Aurelius"),
        Quote(text: "A gem cannot be polished without friction, nor a man perfected without trials.", author: "Seneca"),
        Quote(text: "Fall seven times, stand up eight.", author: "Japanese proverb"),
        Quote(text: "The best time to plant a tree was twenty years ago. The second best time is now.", author: "Proverb"),
        Quote(text: "Discipline is choosing what you want most over what you want now.", author: "Think"),
        Quote(text: "Focus is a decision made every hour.", author: "Think"),
        Quote(text: "Small steps, every day, in the same direction.", author: "Think"),
        Quote(text: "You become what you give your attention to.", author: "Think"),
        Quote(text: "Do it scared.", author: "Think"),
    ]

    static let questions: [String] = [
        "What did you avoid yesterday that you'll face today?",
        "What would today look like if you gave it your full attention?",
        "What is one thing you can do today that your future self will thank you for?",
        "Where are you wasting energy on things you can't control?",
        "What are you pretending not to know?",
        "If today repeated for a year, where would you end up?",
        "What's the smallest step you can take right now on the thing that scares you?",
        "Who do you want to become — and what did you do about it yesterday?",
        "Which distraction costs you the most?",
        "What did you learn yesterday?",
        "Which habit is quietly working against you?",
        "What deserves more of your patience today?",
        "What's one promise you will keep to yourself today?",
        "What would you do today if no one could see the result?",
        "What are you grateful for that you earned?",
    ]

    static func dailyQuote(for date: Date = .now) -> Quote {
        quotes[dayNumber(for: date) % quotes.count]
    }

    static func dailyQuestion(for date: Date = .now) -> String {
        questions[dayNumber(for: date) % questions.count]
    }

    private static func dayNumber(for date: Date) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400)
    }
}
