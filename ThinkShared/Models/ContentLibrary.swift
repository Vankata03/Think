//
//  ContentLibrary.swift
//  Think
//

import Foundation

/// Provenance for attributed text. Ancient authors are not enough: the exact
/// translation must also be clear for copyright review.
nonisolated struct QuoteSource: Codable, Hashable {
    let work: String
    let locator: String
    let edition: String
    let url: String
}

// Codable so bundled practices can later move to a versioned content endpoint.
// Nonisolated because WidgetKit reads them away from the main actor.
nonisolated struct Quote: Identifiable, Codable, Hashable {
    let text: String
    let author: String
    let source: QuoteSource?
    private let localizationKey: String?

    var id: String { localizationKey ?? text }

    init(
        text: String,
        author: String,
        source: QuoteSource? = nil,
        localizationKey: String? = nil
    ) {
        self.text = text
        self.author = author
        self.source = source
        self.localizationKey = localizationKey
    }

    /// House lines remain visually unattributed because the card already carries
    /// the Think wordmark.
    var attribution: String? {
        author == ContentLibrary.houseAuthor ? nil : author
    }

    var notificationText: String {
        attribution.map { "\(text) — \($0)" } ?? text
    }
}

nonisolated struct DailyPractice: Identifiable, Codable, Hashable {
    let quote: Quote
    let question: String
    let action: String

    var id: String { quote.id }
}

nonisolated enum ContentLibrary {

    static let houseAuthor = "Think"

    /// One hundred deliberately paired practices. House lines are original product
    /// copy. Attributed lines reproduce the identified George Long editions;
    /// see docs/content-audit.md for the release policy and audit record.
    private static let sourcePractices: [DailyPractice] = [
        // Attention
        practice(
            original("Your attention is already building a life. The only question is whether you chose the design."),
            "What did your attention build yesterday?",
            "Protect ten minutes for the thing you want your life to contain more of."
        ),
        practice(
            original("The phone is not stealing your attention while it remains within reach. You are lending it."),
            "Which moment today most needs your full presence?",
            "Put your phone in another room for one focused block."
        ),
        practice(
            original("Every open loop charges rent in attention."),
            "Which unfinished thing keeps returning to your mind?",
            "Close it, schedule it, or delete it in the next five minutes."
        ),
        practice(
            original("When everything matters, convenience decides."),
            "What actually deserves your best hour today?",
            "Name one priority and remove one competing task from that hour."
        ),
        practice(
            marcus("Such as are thy habitual thoughts, such also will be the character of thy mind.", "Book V, §16"),
            "Which repeated thought is shaping you in the wrong direction?",
            "Write a more accurate thought and return to it when the old one appears."
        ),
        practice(
            original("The quality of a day is hidden in its transitions."),
            "Where do you lose direction between one task and the next?",
            "Before one transition, stop for three breaths and choose the next action."
        ),
        practice(
            original("More input can be a respectable form of hiding."),
            "What do you already know enough to begin?",
            "Consume nothing about it until you produce one small result."
        ),
        practice(
            original("A full day can still be an empty answer."),
            "Which activity makes you feel productive without moving anything important?",
            "Replace ten minutes of motion with ten minutes of the real work."
        ),
        practice(
            original("Your first hour votes before your ambition wakes up."),
            "What does your first hour currently vote for?",
            "Prepare one useful first-hour action before going to sleep."
        ),
        practice(
            original("Not every thought deserves a meeting."),
            "Which thought keeps taking time without producing a decision?",
            "Give it one written sentence, then return to what is in front of you."
        ),

        // Action
        practice(
            marcus("No longer talk at all about the kind of man that a good man ought to be, but be such.", "Book X, §16"),
            "Which value have you described more often than you have practiced?",
            "Do one visible act that proves it before the day ends."
        ),
        practice(
            original("The task you keep renaming is still the task."),
            "What have you disguised as planning, research, or preparation?",
            "Open it and complete the first visible step now."
        ),
        practice(
            original("You do not need a better mood. You need a smaller starting line."),
            "What feels too large only because the first step is vague?",
            "Shrink the start until it takes two minutes, then do it."
        ),
        practice(
            epictetus("Generally then if you would make anything a habit, do it.", "Discourses, How We Should Struggle Against Appearances"),
            "Which action are you training through repetition, whether you mean to or not?",
            "Replace one repetition of the unwanted habit with its smallest opposite."
        ),
        practice(
            original("A plan that survives no interruption was decoration."),
            "Where is your plan brittle?",
            "Write the minimum version you can still complete on a difficult day."
        ),
        practice(
            original("The next action should be too concrete to argue with."),
            "Which item on your list is still only a category?",
            "Rewrite it as one physical, observable action."
        ),
        practice(
            original("The inbox can be empty while your real work remains untouched."),
            "What important work are small completions helping you avoid?",
            "Work on it for ten minutes before checking messages again."
        ),
        practice(
            original("Confidence built before action is mostly imagination."),
            "What are you waiting to feel ready for?",
            "Take one reversible step while still uncertain."
        ),
        practice(
            epictetus("Nothing great, said Epictetus, is produced suddenly, since not even the grape or the fig is.", "Discourses, What Philosophy Promises"),
            "What result are you demanding before its season?",
            "Do today's repetition and leave the outcome unmeasured until tomorrow."
        ),
        practice(
            original("Later is a real choice with an invisible receipt."),
            "What will delay cost if repeated for a month?",
            "Pay two minutes toward it now instead."
        ),

        // Discipline
        practice(
            original("Discipline is less about force than removing the next argument."),
            "Which useful choice do you renegotiate every day?",
            "Set one default that makes tomorrow's choice automatic."
        ),
        practice(
            original("Missing once is weather. Missing twice is a route."),
            "What needs a gentle return today?",
            "Do the smallest complete version before bedtime."
        ),
        practice(
            original("A standard you cannot practice on a bad day is a performance."),
            "What is the honest minimum for your hardest days?",
            "Define it in one sentence and practice it today."
        ),
        practice(
            original("Make the right action easier before asking yourself to become stronger."),
            "What in your environment keeps voting against your intention?",
            "Move, block, or prepare one object so the better action becomes easier."
        ),
        practice(
            original("If your system needs heroics, it is not a system yet."),
            "Where are you relying on last-minute effort?",
            "Add one checkpoint before the deadline."
        ),
        practice(
            epictetus("Begin then from little things.", "Encheiridion, §12"),
            "What change have you rejected because the first version looked too small?",
            "Choose the smallest repetition that still counts and complete it."
        ),
        practice(
            original("Measure the return, not the drift."),
            "How quickly do you return after attention, mood, or routine slips?",
            "Practice one immediate, unpunished return today."
        ),
        practice(
            original("The promise after failure matters less than the environment changed before tomorrow."),
            "What made the last failure predictable?",
            "Change one condition before making another promise."
        ),
        practice(
            original("What you repeat in private becomes your public limit."),
            "Which private repetition is lowering your standard?",
            "Interrupt it once today and record what triggered it."
        ),
        practice(
            original("Rest that restores you is training. Escape that numbs you sends an invoice."),
            "Which kind of rest leaves you more available to life?",
            "Take ten minutes of that kind without a feed or notification."
        ),

        // Control and uncertainty
        practice(
            epictetus("Of things some are in our power, and others are not.", "Encheiridion, §1"),
            "Which part of today's problem is actually yours to act on?",
            "Draw two columns—mine and not mine—then act on one item from the first."
        ),
        practice(
            original("Worry rehearses pain, not response."),
            "What specific event are you worried about?",
            "Write one response you could take if it happens, then stop rehearsing it."
        ),
        practice(
            original("Name the fact before you name the catastrophe."),
            "What do you know, and what have you added?",
            "Write the observable facts without predictions or motives."
        ),
        practice(
            epictetus("Men are disturbed not by the things which happen, but by the opinions about the things.", "Encheiridion, §5"),
            "Which opinion is intensifying a difficult fact?",
            "Replace one absolute word—always, never, ruined—with a precise description."
        ),
        practice(
            original("You cannot protect every option and still choose."),
            "Which decision stays open because closing doors feels like loss?",
            "Choose one reversible direction and give it a date for review."
        ),
        practice(
            epictetus("Seek not that the things which happen should happen as you wish.", "Encheiridion, §8"),
            "What reality are you spending energy refusing?",
            "State it without approval or complaint, then choose your response."
        ),
        practice(
            original("Certainty feels clean because it hides the unfinished work."),
            "Where are you more certain than your evidence allows?",
            "Write one fact that would change your mind."
        ),
        practice(
            marcus("Nothing happens to any man which he is not formed by nature to bear.", "Book V, §18"),
            "Which capacity has a past difficulty already proven in you?",
            "Name that capacity and use it on the next ten minutes."
        ),
        practice(
            original("A decision you revisit daily is a leak."),
            "Which settled choice keeps consuming fresh attention?",
            "Write a rule and a date when you are allowed to reconsider it."
        ),
        practice(
            original("A day can fail its plan and still serve its purpose."),
            "What still matters now that today changed?",
            "Choose one useful act that fits the day you actually have."
        ),

        // Courage and avoidance
        practice(
            original("Avoidance makes small doors look like walls."),
            "What has grown in your mind while remaining untouched?",
            "Approach it for five minutes without requiring completion."
        ),
        practice(
            original("Courage is not volume. Sometimes it is one unedited sentence."),
            "What true sentence are you softening past recognition?",
            "Write it plainly; decide later whether it should be sent."
        ),
        practice(
            epictetus("But let the thing wait for you.", "Encheiridion, §34"),
            "Which impulse gets stronger because you obey it immediately?",
            "Place a ten-minute delay between the impulse and the choice."
        ),
        practice(
            original("You are allowed to disappoint the version of you that chose badly."),
            "Which old commitment survives only because changing feels inconsistent?",
            "Write what you know now that you did not know when you chose it."
        ),
        practice(
            epictetus("But if it is right, why are you afraid of those who shall find fault wrongly?", "Encheiridion, §35"),
            "Which right action are you hiding to avoid being judged?",
            "Take one visible step without writing a defense for it."
        ),
        practice(
            original("The life you want may be buried under commitments kept only to avoid awkwardness."),
            "Which commitment would you decline if it were offered today?",
            "Draft the respectful no, even if you do not send it yet."
        ),
        practice(
            original("The fear of looking foolish has buried more practice than failure ever could."),
            "Where are you protecting competence instead of building it?",
            "Do one beginner repetition where the result can be imperfect."
        ),
        practice(
            original("Comfort is useful for recovery and expensive as a compass."),
            "Which choice is being made by comfort alone?",
            "Add one small, deliberate discomfort that serves what matters."
        ),
        practice(
            original("The honest answer usually appears before the impressive one."),
            "What was your first honest answer before you edited it?",
            "Write it in ten words without explaining yourself."
        ),
        practice(
            marcus("A man then must stand erect, not be kept erect by others.", "Book III, §5"),
            "Where are you waiting for encouragement before acting?",
            "Begin one useful action without announcing it."
        ),

        // Truth and clear thinking
        practice(
            original("Your strongest belief deserves your strongest test."),
            "Which belief is important enough to risk correcting?",
            "Find the strongest evidence against it and summarize it fairly."
        ),
        practice(
            original("An opinion inherited unnoticed still directs your life."),
            "Which rule do you follow without remembering choosing it?",
            "Write whose rule it was and whether it still earns authority."
        ),
        practice(
            original("Changing your mind is not losing when truth is the score."),
            "When did new evidence last change an important view?",
            "Name one current view you hold provisionally rather than permanently."
        ),
        practice(
            original("The person you disagree with may be wrong; your summary of them can still be dishonest."),
            "Could they recognize their position in your description?",
            "Rewrite their case until they plausibly could."
        ),
        practice(
            original("Speed hides questions that patience would force you to answer."),
            "Where are you rushing because stopping might change the plan?",
            "Pause for five minutes and write the question speed is hiding."
        ),
        practice(
            marcus("Make for thyself a definition or description of the thing which is presented to thee.", "Book III, §11"),
            "What becomes clearer when stripped of its flattering or frightening label?",
            "Describe it using only observable details."
        ),
        practice(
            original("You may be optimizing the part that is easiest to measure."),
            "Which metric looks good while the real outcome stays unchanged?",
            "Name one harder-to-measure sign of actual progress."
        ),
        practice(
            original("The story you tell about yourself selects the evidence."),
            "Which self-story filters out contradictory facts?",
            "Record one true example that the story cannot comfortably explain."
        ),
        practice(
            original("Read less. Argue with more of it."),
            "Which idea have you collected without testing?",
            "Write one objection and one practical consequence."
        ),
        practice(
            original("Curiosity begins where the need to look informed ends."),
            "What would you ask if you were not protecting your image?",
            "Ask one basic question without apologizing for it."
        ),

        // Identity and standards
        practice(
            original("Identity should explain your practice, not excuse it."),
            "Which label lets you avoid changing a behavior?",
            "Describe the behavior without using the label."
        ),
        practice(
            original("Private standards are where character stops performing."),
            "What standard matters even when nobody can reward you?",
            "Keep one private promise today and do not announce it."
        ),
        practice(
            original("Your values are easier to find in your refusals than in your bio."),
            "What deserves a no so a real value can receive a yes?",
            "Refuse, cancel, or reduce one low-value demand."
        ),
        practice(
            epictetus("There is no limit to that which has once passed the true measure.", "Encheiridion, §39"),
            "Which role is consuming energy that belongs to work you can truly do?",
            "Reduce one promise to an honest, finishable scope."
        ),
        practice(
            original("If the work matters only when witnessed, inspect the audience."),
            "Whose reaction has become part of your reason for doing this?",
            "Do ten minutes of the work with no plan to share the result."
        ),
        practice(
            original("You are not your worst day, but you are responsible for the next move."),
            "What repair is available without turning failure into identity?",
            "Make the smallest repair before explaining what happened."
        ),
        practice(
            original("A borrowed goal can consume an original life."),
            "Which goal sounds admirable but does not feel chosen?",
            "Write what you would pursue if nobody could compare the result."
        ),
        practice(
            original("Self-respect grows from evidence, not affirmations."),
            "What promise would give you useful evidence today?",
            "Make it small enough to keep before the day ends."
        ),
        practice(
            marcus("Never value anything as profitable to thyself which shall compel thee to break thy promise.", "Book III, §7"),
            "Which apparent advantage asks you to become someone you would not respect?",
            "Name the cost in character before deciding."
        ),
        practice(
            original("Who you become is partly the cost you stop making others pay."),
            "Which of your patterns creates work, worry, or silence for someone else?",
            "Take responsibility for one part without adding a justification."
        ),

        // Relationships and boundaries
        practice(
            original("A delayed no becomes a dishonest yes."),
            "Where is politeness creating a promise you cannot keep?",
            "Give one clear answer before resentment gives it for you."
        ),
        practice(
            original("A boundary explained ten times is a negotiation."),
            "Which boundary needs enforcement rather than another argument?",
            "State the consequence once and follow through calmly."
        ),
        practice(
            original("Being understood is not the same as being agreed with."),
            "Are you asking for comprehension or surrender?",
            "State your view once, then ask the other person to summarize it."
        ),
        practice(
            original("Listen for the request underneath the complaint."),
            "What might this person need but not know how to ask for?",
            "Ask one clarifying question before offering a solution."
        ),
        practice(
            original("The hardest conversation grows interest while you avoid it."),
            "What is getting more expensive because it remains unsaid?",
            "Write the opening sentence and choose a time for the conversation."
        ),
        practice(
            original("Attention is one of the few gifts that cannot be given later."),
            "Who receives your proximity but not your presence?",
            "Give them ten minutes with every screen out of reach."
        ),
        practice(
            original("Ask before helping; rescue can be control wearing kindness."),
            "Where might your help be replacing another person's choice?",
            "Ask what support they want before acting."
        ),
        practice(
            original("An apology without changed logistics is a request to forget."),
            "What practical change would make your apology believable?",
            "Change the reminder, boundary, schedule, or system today."
        ),
        practice(
            epictetus("Everything has two handles, the one by which it may be borne, the other by which it may not.", "Encheiridion, §43"),
            "Which interpretation of this conflict makes a useful response possible?",
            "Describe the same event from the most workable honest angle."
        ),
        practice(
            original("You can leave room for someone without leaving yourself out."),
            "Where has care become self-erasure?",
            "Include one of your own needs in the next decision."
        ),

        // Learning and craft
        practice(
            original("Learning that never changes a choice is storage."),
            "What have you learned but not used?",
            "Apply one idea to a real decision today."
        ),
        practice(
            original("The note you take is not the lesson. The retrieval is."),
            "What could you explain without reopening the source?",
            "Close the source and write five points from memory."
        ),
        practice(
            original("Practice exposes the questions that preparation keeps theoretical."),
            "What can only be learned by attempting it?",
            "Run one small trial and record where reality disagrees with your plan."
        ),
        practice(
            original("Finishing teaches a different subject than starting."),
            "Which nearly finished piece of work could teach you about completion?",
            "Spend ten minutes on its final uncomfortable part."
        ),
        practice(
            original("Feedback avoided becomes a ceiling chosen."),
            "Whose honest reaction could improve the work?",
            "Ask for one specific criticism, not general approval."
        ),
        practice(
            original("A mistake studied once can pay rent for years."),
            "What did your last mistake reveal about the process?",
            "Write one prevention rule where you will see it next time."
        ),
        practice(
            original("Clarity often arrives after subtraction, not addition."),
            "What can be removed without harming the essential result?",
            "Delete one step, feature, paragraph, or commitment."
        ),
        practice(
            original("The draft is where taste stops being a spectator."),
            "What judgment are you making without producing anything to judge?",
            "Make an intentionally rough first version in ten minutes."
        ),
        practice(
            original("Repetition without observation hardens mistakes."),
            "What do you repeat without checking whether it improves?",
            "Choose one detail to observe during today's repetition."
        ),
        practice(
            original("The useful question is often the one that changes the work, not the one that displays knowledge."),
            "Which question would alter what you do next?",
            "Answer it with a test, not another opinion."
        ),

        // Time and direction
        practice(
            original("Time is not only spent. It is traded for a particular self."),
            "Who are your repeated hours training you to become?",
            "Trade ten minutes from a default activity to a chosen one."
        ),
        practice(
            original("A year changes at the level of ordinary Tuesdays."),
            "What ordinary-day behavior would make the year different?",
            "Practice it once today at a time you can repeat next week."
        ),
        practice(
            marcus("Bear in mind that every man lives only this present time.", "Book III, §10"),
            "What deserves the present hour rather than a vague future promise?",
            "Choose one thing and give it the next uninterrupted ten minutes."
        ),
        practice(
            original("A goal without a subtraction is a wish for extra hours."),
            "What will receive less time if this goal is real?",
            "Remove one recurring activity from the calendar."
        ),
        practice(
            original("The deadline is not the only thing making this moment finite."),
            "What are you postponing as if the opportunity were permanent?",
            "Take one step while the person, health, access, or season is still here."
        ),
        practice(
            original("Some seasons are for expansion; others are for keeping one promise alive."),
            "What season are you actually in?",
            "Choose the one promise that must survive this week."
        ),
        practice(
            marcus("Do not disturb thyself by thinking of the whole of thy life.", "Book VIII, §36"),
            "Which imagined future is making the present task heavier?",
            "Reduce the horizon to what can be handled in the next ten minutes."
        ),
        practice(
            original("You do not owe every hour productivity; you owe important hours honesty."),
            "Is this hour for work, rest, or avoidance?",
            "Name it truthfully and do that one thing without mixing the others into it."
        ),
        practice(
            original("Before adding a goal, decide what will receive less life."),
            "Which existing commitment must shrink for the new one to fit?",
            "Write the tradeoff beside the goal before accepting it."
        ),
        practice(
            original("End the day by reducing tomorrow's first decision."),
            "What choice could your tired evening self make for your morning self?",
            "Prepare the first task, tool, and starting time before bed."
        ),
    ]

    /// Content uses stable catalog keys rather than English prose as identity.
    /// Preserve source order; append new practices instead of inserting them.
    static let practices: [DailyPractice] = sourcePractices.enumerated().map { index, source in
        let key = String(format: "practice.%03d", index + 1)
        return DailyPractice(
            quote: Quote(
                text: localizedContent("\(key).line", fallback: source.quote.text),
                author: localizedContent("\(key).author", fallback: source.quote.author),
                source: source.quote.source,
                localizationKey: key
            ),
            question: localizedContent("\(key).question", fallback: source.question),
            action: localizedContent("\(key).action", fallback: source.action)
        )
    }

    static let quotes = practices.map(\.quote)
    static let questions = practices.map(\.question)
    static let actions = practices.map(\.action)

    static func dailyPractice(for date: Date = .now) -> DailyPractice {
        practices[dayNumber(for: date) % practices.count]
    }

    static func dailyQuote(for date: Date = .now) -> Quote {
        dailyPractice(for: date).quote
    }

    static func dailyQuestion(for date: Date = .now) -> String {
        dailyPractice(for: date).question
    }

    static func dailyAction(for date: Date = .now) -> String {
        dailyPractice(for: date).action
    }

    private static func practice(
        _ quote: Quote,
        _ question: String,
        _ action: String
    ) -> DailyPractice {
        DailyPractice(quote: quote, question: question, action: action)
    }

    private static func original(_ text: String) -> Quote {
        Quote(text: text, author: houseAuthor)
    }

    private static func marcus(_ text: String, _ locator: String) -> Quote {
        Quote(
            text: text,
            author: "Marcus Aurelius",
            source: QuoteSource(
                work: "Thoughts of Marcus Aurelius",
                locator: locator,
                edition: "George Long translation (1862); translator died 1879",
                url: "https://www.gutenberg.org/ebooks/6920"
            )
        )
    }

    private static func epictetus(_ text: String, _ locator: String) -> Quote {
        Quote(
            text: text,
            author: "Epictetus",
            source: QuoteSource(
                work: "A Selection from the Discourses of Epictetus with the Encheiridion",
                locator: locator,
                edition: "George Long translation; translator died 1879",
                url: "https://www.gutenberg.org/ebooks/10661"
            )
        )
    }

    private static func localizedContent(_ key: String, fallback: String) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback, table: "Content")
    }

    /// Calendar-based day ordinal. Seconds math repeats or skips local days at
    /// daylight-saving transitions.
    private static func dayNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        let reference = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let day = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: reference, to: day).day ?? 0)
    }
}
