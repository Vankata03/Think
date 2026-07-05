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
        Quote(text: "It is not death that a man should fear, but he should fear never beginning to live.", author: "Marcus Aurelius"),
        Quote(text: "Dwell on the beauty of life. Watch the stars, and see yourself running with them.", author: "Marcus Aurelius"),
        Quote(text: "Loss is nothing else but change, and change is Nature's delight.", author: "Marcus Aurelius"),
        Quote(text: "Be tolerant with others and strict with yourself.", author: "Marcus Aurelius"),
        Quote(text: "The happiness of your life depends upon the quality of your thoughts.", author: "Marcus Aurelius"),
        Quote(text: "Receive without pride, let go without attachment.", author: "Marcus Aurelius"),
        Quote(text: "What we do now echoes in eternity.", author: "Marcus Aurelius"),

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
        Quote(text: "All cruelty springs from weakness.", author: "Seneca"),
        Quote(text: "The mind that is anxious about future events is miserable.", author: "Seneca"),
        Quote(text: "He suffers more than necessary, who suffers before it is necessary.", author: "Seneca"),
        Quote(text: "Associate with people who are likely to improve you.", author: "Seneca"),
        Quote(text: "Nothing is ours except time.", author: "Seneca"),
        Quote(text: "Life is long if you know how to use it.", author: "Seneca"),
        Quote(text: "Sometimes even to live is an act of courage.", author: "Seneca"),

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
        Quote(text: "Seek not the good in external things; seek it in yourselves.", author: "Epictetus"),
        Quote(text: "It is impossible for a man to learn what he thinks he already knows.", author: "Epictetus"),
        Quote(text: "No great thing is created suddenly.", author: "Epictetus"),
        Quote(text: "First learn the meaning of what you say, and then speak.", author: "Epictetus"),

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
        Quote(text: "Wise men learn more from fools than fools from the wise.", author: "Cato the Elder"),
        Quote(text: "He has the most who is most content with the least.", author: "Diogenes"),
        Quote(text: "Employ your time in improving yourself by other men's writings.", author: "Socrates"),
        Quote(text: "The beginning is the most important part of the work.", author: "Plato"),
        Quote(text: "Do not say a little in many words but a great deal in a few.", author: "Pythagoras"),
        Quote(text: "The most difficult thing in life is to know yourself.", author: "Thales"),
        Quote(text: "Practice is the best of all instructors.", author: "Publilius Syrus"),
        Quote(text: "It takes a long time to bring excellence to maturity.", author: "Publilius Syrus"),
        Quote(text: "Begin, be bold, and venture to be wise.", author: "Horace"),
        Quote(text: "Rule your mind or it will rule you.", author: "Horace"),
        Quote(text: "Take rest; a field that has rested gives a bountiful crop.", author: "Ovid"),
        Quote(text: "Gratitude is not only the greatest of virtues, but the parent of all others.", author: "Cicero"),

        // Eastern classics
        Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        Quote(text: "The man who moves a mountain begins by carrying away small stones.", author: "Confucius"),
        Quote(text: "A journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        Quote(text: "Mastering others is strength. Mastering yourself is true power.", author: "Lao Tzu"),
        Quote(text: "Nature does not hurry, yet everything is accomplished.", author: "Lao Tzu"),
        Quote(text: "Real knowledge is to know the extent of one's ignorance.", author: "Confucius"),
        Quote(text: "Our greatest glory is not in never falling, but in rising every time we fall.", author: "Confucius"),
        Quote(text: "He who conquers himself is the mightiest warrior.", author: "Confucius"),
        Quote(text: "Knowing others is intelligence; knowing yourself is true wisdom.", author: "Lao Tzu"),
        Quote(text: "Do the difficult things while they are easy and do the great things while they are small.", author: "Lao Tzu"),
        Quote(text: "All that we are is the result of what we have thought.", author: "Buddha"),
        Quote(text: "It is better to conquer yourself than to win a thousand battles.", author: "Buddha"),

        // Pre-1900 authors
        Quote(text: "Well done is better than well said.", author: "Benjamin Franklin"),
        Quote(text: "Energy and persistence conquer all things.", author: "Benjamin Franklin"),
        Quote(text: "Lost time is never found again.", author: "Benjamin Franklin"),
        Quote(text: "It is not enough to be busy; so are the ants. The question is: what are we busy about?", author: "Henry David Thoreau"),
        Quote(text: "In the long run, men hit only what they aim at.", author: "Henry David Thoreau"),
        Quote(text: "You may delay, but time will not.", author: "Benjamin Franklin"),
        Quote(text: "Diligence is the mother of good luck.", author: "Benjamin Franklin"),

        // Proverbs and fables
        Quote(text: "Fall seven times, stand up eight.", author: "Japanese proverb"),
        Quote(text: "The best time to plant a tree was twenty years ago. The second best time is now.", author: "Proverb"),
        Quote(text: "Slow but steady wins the race.", author: "Aesop"),
        Quote(text: "The obstacle is the path.", author: "Zen proverb"),
        Quote(text: "Fortune favors the bold.", author: "Latin proverb"),
        Quote(text: "Be not afraid of going slowly, be afraid only of standing still.", author: "Chinese proverb"),
        Quote(text: "A smooth sea never made a skilled sailor.", author: "English proverb"),
        Quote(text: "Little by little, one travels far.", author: "Spanish proverb"),
        Quote(text: "When the winds of change blow, some build walls, others build windmills.", author: "Chinese proverb"),
        Quote(text: "Vision without action is a daydream. Action without vision is a nightmare.", author: "Japanese proverb"),
        Quote(text: "After the rain, the earth hardens.", author: "Japanese proverb"),

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
        Quote(text: "Motivation starts the work. Habit finishes it.", author: houseAuthor),
        Quote(text: "You don't find time. You take it.", author: houseAuthor),
        Quote(text: "The plan is not the practice.", author: houseAuthor),
        Quote(text: "Begin again. That is the whole secret.", author: houseAuthor),
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
        "What does the best version of today look like?",
        "Which task have you been circling without starting?",
        "What drained you yesterday that you could cut today?",
        "What did you say yes to that you should have refused?",
        "Where are you confusing motion with progress?",
        "What would you tell a friend in your exact situation?",
        "What is the one thing that makes everything else easier today?",
        "Which fear shrank the last time you faced it?",
        "What are you optimizing that doesn't matter?",
        "When did you last change your mind about something important?",
        "What is your evening self hoping your morning self does?",
        "Which relationship deserves ten minutes today?",
        "What are you carrying that isn't yours to carry?",
        "What would you start today if you were guaranteed to be bad at it for a month?",
        "Which small win yesterday deserves to be repeated?",
        "What is the truth you keep negotiating with?",
        "Where does your first hour of the day actually go?",
        "What would you do differently if this week were your review?",
        "Which promise to someone else is costing a promise to yourself?",
        "What boring thing, done daily, would change your year?",
        "What are you waiting for permission to do?",
        "Which input — news, feed, person — leaves you worse every time?",
        "What did you handle well yesterday?",
        "Where would slowing down actually speed you up?",
        "What does your body need today that you keep skipping?",
        "Which decision are you re-making every day instead of once?",
        "What would make future-you proud tonight?",
        "What is the smallest version of the thing you're avoiding?",
        "Who did you help yesterday?",
        "What are you sure of that you haven't tested?",
        "Which corner are you cutting that will cost you later?",
        "What deserves your best hour today?",
        "If you could only finish one thing today, what should it be?",
        "What old goal are you chasing out of momentum, not desire?",
        "Where did you choose comfort over growth yesterday?",
        "What compliment do you deflect that you should accept?",
        "What would you do with one distraction-free hour today?",
        "Which habit would you be embarrassed to explain?",
        "What is one thing you know you should measure but don't?",
        "Whose work do you admire — and what does that say about your direction?",
        "What's the kindest hard thing you could do today?",
        "Which excuse have you used twice this week?",
        "What would today look like with half the inputs and twice the output?",
        "What did yesterday teach you about what to stop?",
        "Where are you performing instead of practicing?",
        "What question are you hoping nobody asks you?",
        "What would you defend today if it got hard at noon?",
        "Which memory proves you can do difficult things?",
        "What does 'done' look like for today's most important task?",
        "If you met yourself today, what advice would you give?",
    ]

    static func dailyQuote(for date: Date = .now) -> Quote {
        quotes[dayNumber(for: date) % quotes.count]
    }

    static func dailyQuestion(for date: Date = .now) -> String {
        questions[dayNumber(for: date) % questions.count]
    }

    /// Calendar-based day ordinal. Seconds math (`interval / 86_400`)
    /// repeats or skips days across DST transitions, where local
    /// midnights are not 24 hours apart.
    private static func dayNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        let reference = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let day = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: reference, to: day).day ?? 0)
    }
}
