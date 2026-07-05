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

    /// Author line for display. House-written lines carry the brand as
    /// author and show no separate attribution — the card's wordmark
    /// already says Think.
    var attribution: String? {
        author == ContentLibrary.houseAuthor ? nil : author
    }
}

nonisolated enum ContentLibrary {

    /// Author value marking original Think lines.
    static let houseAuthor = "Think"

    // Public-domain sources (Stoics, classical authors, proverbs) plus
    // original lines only — modern-author quotes are a licensing risk
    // (see PLAN.md). Keep attributions to widely documented traditional
    // ones; when an attribution is disputed, the quote doesn't ship.
    static let quotes: [Quote] = [
        // Marcus Aurelius
        Quote(text: "You have power over your mind — not outside events. Realize this, and you will find strength.", author: "Marcus Aurelius"),
        Quote(text: "Waste no more time arguing about what a good man should be. Be one.", author: "Marcus Aurelius"),
        Quote(text: "The impediment to action advances action. What stands in the way becomes the way.", author: "Marcus Aurelius"),
        Quote(text: "Confine yourself to the present.", author: "Marcus Aurelius"),
        Quote(text: "If it is not right, do not do it; if it is not true, do not say it.", author: "Marcus Aurelius"),
        Quote(text: "The best revenge is to be unlike him who performed the injury.", author: "Marcus Aurelius"),
        Quote(text: "Very little is needed to make a happy life; it is all within yourself, in your way of thinking.", author: "Marcus Aurelius"),
        Quote(text: "When you arise in the morning, think of what a precious privilege it is to be alive.", author: "Marcus Aurelius"),
        Quote(text: "The soul becomes dyed with the color of its thoughts.", author: "Marcus Aurelius"),
        Quote(text: "Do every act of your life as though it were the last act of your life.", author: "Marcus Aurelius"),
        Quote(text: "Look well into thyself; there is a source of strength which will always spring up if thou wilt always look.", author: "Marcus Aurelius"),
        Quote(text: "He who lives in harmony with himself lives in harmony with the universe.", author: "Marcus Aurelius"),

        // Seneca
        Quote(text: "We suffer more often in imagination than in reality.", author: "Seneca"),
        Quote(text: "Luck is what happens when preparation meets opportunity.", author: "Seneca"),
        Quote(text: "It is not that we have a short time to live, but that we waste a lot of it.", author: "Seneca"),
        Quote(text: "Difficulties strengthen the mind, as labor does the body.", author: "Seneca"),
        Quote(text: "While we wait for life, life passes.", author: "Seneca"),
        Quote(text: "A gem cannot be polished without friction, nor a man perfected without trials.", author: "Seneca"),
        Quote(text: "It is a rough road that leads to the heights of greatness.", author: "Seneca"),
        Quote(text: "He who is brave is free.", author: "Seneca"),
        Quote(text: "Begin at once to live, and count each separate day as a separate life.", author: "Seneca"),
        Quote(text: "No man was ever wise by chance.", author: "Seneca"),
        Quote(text: "If a man knows not to which port he sails, no wind is favorable.", author: "Seneca"),
        Quote(text: "Time discovers truth.", author: "Seneca"),

        // Epictetus
        Quote(text: "No man is free who is not master of himself.", author: "Epictetus"),
        Quote(text: "First say to yourself what you would be; and then do what you have to do.", author: "Epictetus"),
        Quote(text: "How long are you going to wait before you demand the best for yourself?", author: "Epictetus"),
        Quote(text: "Wealth consists not in having great possessions, but in having few wants.", author: "Epictetus"),
        Quote(text: "Only the educated are free.", author: "Epictetus"),
        Quote(text: "Circumstances don't make the man, they only reveal him to himself.", author: "Epictetus"),
        Quote(text: "If you want to improve, be content to be thought foolish and stupid.", author: "Epictetus"),
        Quote(text: "Don't explain your philosophy. Embody it.", author: "Epictetus"),
        Quote(text: "He is a wise man who does not grieve for the things which he has not, but rejoices for those which he has.", author: "Epictetus"),

        // Other Stoics and classical authors
        Quote(text: "Man conquers the world by conquering himself.", author: "Zeno of Citium"),
        Quote(text: "Well-being is realized by small steps, but is truly no small thing.", author: "Zeno of Citium"),
        Quote(text: "Character is destiny.", author: "Heraclitus"),
        Quote(text: "No man ever steps in the same river twice.", author: "Heraclitus"),
        Quote(text: "The unexamined life is not worth living.", author: "Socrates"),
        Quote(text: "The first and greatest victory is to conquer yourself.", author: "Plato"),
        Quote(text: "To do two things at once is to do neither.", author: "Publilius Syrus"),
        Quote(text: "No man is happy who does not think himself so.", author: "Publilius Syrus"),
        Quote(text: "While there's life, there's hope.", author: "Cicero"),
        Quote(text: "Dripping water hollows out stone, not through force but through persistence.", author: "Ovid"),
        Quote(text: "Do not spoil what you have by desiring what you have not.", author: "Epicurus"),
        Quote(text: "Happiness resides not in possessions, and not in gold; happiness dwells in the soul.", author: "Democritus"),

        // Eastern classics
        Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        Quote(text: "The man who moves a mountain begins by carrying away small stones.", author: "Confucius"),
        Quote(text: "A journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        Quote(text: "Mastering others is strength. Mastering yourself is true power.", author: "Lao Tzu"),
        Quote(text: "Nature does not hurry, yet everything is accomplished.", author: "Lao Tzu"),

        // Pre-1900 authors
        Quote(text: "Well done is better than well said.", author: "Benjamin Franklin"),
        Quote(text: "Energy and persistence conquer all things.", author: "Benjamin Franklin"),
        Quote(text: "Lost time is never found again.", author: "Benjamin Franklin"),
        Quote(text: "It is not enough to be busy; so are the ants. The question is: what are we busy about?", author: "Henry David Thoreau"),

        // Proverbs and fables
        Quote(text: "Fall seven times, stand up eight.", author: "Japanese proverb"),
        Quote(text: "The best time to plant a tree was twenty years ago. The second best time is now.", author: "Proverb"),
        Quote(text: "Slow but steady wins the race.", author: "Aesop"),
        Quote(text: "The obstacle is the path.", author: "Zen proverb"),
        Quote(text: "Fortune favors the bold.", author: "Latin proverb"),
        Quote(text: "Be not afraid of going slowly, be afraid only of standing still.", author: "Chinese proverb"),

        // Original Think lines
        Quote(text: "Discipline is choosing what you want most over what you want now.", author: houseAuthor),
        Quote(text: "Focus is a decision made every hour.", author: houseAuthor),
        Quote(text: "Small steps, every day, in the same direction.", author: houseAuthor),
        Quote(text: "You become what you give your attention to.", author: houseAuthor),
        Quote(text: "Do it scared.", author: houseAuthor),
        Quote(text: "The streak is not the goal. The person you become is.", author: houseAuthor),
        Quote(text: "One honest sentence beats ten perfect plans.", author: houseAuthor),
        Quote(text: "Attention is the rarest currency. Spend it on purpose.", author: houseAuthor),
        Quote(text: "Hard days build the habit. Easy days test it.", author: houseAuthor),
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
        "What would make today feel like a win by tonight?",
        "What are you tolerating that you should fix?",
        "Where did your attention actually go yesterday?",
        "What conversation are you avoiding?",
        "What would you attempt if failure cost nothing?",
        "Which of yesterday's worries actually happened?",
        "What do you need less of?",
        "Whose approval are you working for — and why?",
        "What's the most useful thing you could stop doing?",
        "When were you most focused this week, and what made it possible?",
        "What small thing done today compounds in a year?",
        "What are you putting off that takes less than ten minutes?",
        "If a friend described your yesterday, what would they say you value?",
        "What rule do you keep breaking with yourself?",
        "What is in your control today, and what is not?",
        "What would 'enough' look like today?",
        "Which strength did you not use yesterday?",
        "What is the honest reason behind your last excuse?",
        "What did you do yesterday only out of habit?",
        "Where can you choose quality over speed today?",
        "What would you do today if you fully trusted yourself?",
        "What lesson keeps returning until you learn it?",
        "What are you building — and does today's plan serve it?",
        "Which discomfort, faced today, buys freedom tomorrow?",
        "What deserves a 'no' today so something better gets a 'yes'?",
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
