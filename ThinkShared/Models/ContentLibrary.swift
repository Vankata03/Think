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
        source == nil ? nil : author
    }

    var notificationText: String {
        attribution.map { "\(text) — \($0)" } ?? text
    }
}

nonisolated struct DailyPractice: Identifiable, Codable, Hashable {
    let quote: Quote
    let question: String
    let action: String
    let version: Int
    let tags: [PracticeTheme]
    let estimatedMinutes: Int

    init(quote: Quote, question: String, action: String, version: Int = 1,
         tags: [PracticeTheme] = [], estimatedMinutes: Int = 5) {
        self.quote = quote
        self.question = question
        self.action = action
        self.version = version
        self.tags = tags
        self.estimatedMinutes = estimatedMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case quote, question, action, version, tags, estimatedMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quote = try c.decode(Quote.self, forKey: .quote)
        question = try c.decode(String.self, forKey: .question)
        action = try c.decode(String.self, forKey: .action)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        tags = try c.decodeIfPresent([PracticeTheme].self, forKey: .tags) ?? []
        estimatedMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 5
    }

    var id: String { quote.id }
}

nonisolated enum PracticeTheme: String, Codable, CaseIterable {
    case focus, action, consistency, clarity, courage, identity, connection, learning, direction
    case recovery, enough, kindness, curiosity, boundaries, joy
}

/// Optional local discovery preferences. They never change the shared daily assignment.
nonisolated struct PracticePreference: Codable, Hashable {
    var theme: PracticeTheme? = nil
    var maximumMinutes: Int? = nil
}

nonisolated enum ContentLibrary {

    static let houseAuthor = "Think"

    /// One hundred deliberately paired practices. House lines are original product
    /// copy. Attributed lines reproduce the identified George Long editions;
    /// see docs/content-audit.md for the release policy and audit record.
    private static let sourcePractices: [DailyPractice] = [
        // Attention
        practice("practice.001",
            original("Your attention is already building a life. The only question is whether you chose the design."),
            "What did your attention build yesterday?",
            "Protect ten minutes for the thing you want your life to contain more of."
        ),
        practice("practice.002",
            original("The phone is not stealing your attention while it remains within reach. You are lending it."),
            "Which moment today most needs your full presence?",
            "Put your phone in another room for one focused block."
        ),
        practice("practice.003",
            original("Every open loop charges rent in attention."),
            "Which unfinished thing keeps returning to your mind?",
            "Close it, schedule it, or delete it in the next five minutes."
        ),
        practice("practice.004",
            original("When everything matters, convenience decides."),
            "What actually deserves your best hour today?",
            "Name one priority and remove one competing task from that hour."
        ),
        practice("practice.005",
            marcus("Such as are thy habitual thoughts, such also will be the character of thy mind.", "Book V, §16"),
            "Which repeated thought is shaping you in the wrong direction?",
            "Write a more accurate thought and return to it when the old one appears."
        ),
        practice("practice.006",
            original("The quality of a day is hidden in its transitions."),
            "Where do you lose direction between one task and the next?",
            "Before one transition, stop for three breaths and choose the next action."
        ),
        practice("practice.007",
            original("More input can be a respectable form of hiding."),
            "What do you already know enough to begin?",
            "Consume nothing about it until you produce one small result."
        ),
        practice("practice.008",
            original("A full day can still be an empty answer."),
            "Which activity makes you feel productive without moving anything important?",
            "Replace ten minutes of motion with ten minutes of the real work."
        ),
        practice("practice.009",
            original("Your first hour votes before your ambition wakes up."),
            "What does your first hour currently vote for?",
            "Prepare one useful first-hour action before going to sleep."
        ),
        practice("practice.010",
            original("Not every thought deserves a meeting."),
            "Which thought keeps taking time without producing a decision?",
            "Give it one written sentence, then return to what is in front of you."
        ),

        // Action
        practice("practice.011",
            marcus("No longer talk at all about the kind of man that a good man ought to be, but be such.", "Book X, §16"),
            "Which value have you described more often than you have practiced?",
            "Do one visible act that proves it before the day ends."
        ),
        practice("practice.012",
            original("The task you keep renaming is still the task."),
            "What have you disguised as planning, research, or preparation?",
            "Open it and complete the first visible step now."
        ),
        practice("practice.013",
            original("You do not need a better mood. You need a smaller starting line."),
            "What feels too large only because the first step is vague?",
            "Shrink the start until it takes two minutes, then do it."
        ),
        practice("practice.014",
            epictetus("Generally then if you would make anything a habit, do it.", "Discourses, How We Should Struggle Against Appearances"),
            "Which action are you training through repetition, whether you mean to or not?",
            "Replace one repetition of the unwanted habit with its smallest opposite."
        ),
        practice("practice.015",
            original("A plan that survives no interruption was decoration."),
            "Where is your plan brittle?",
            "Write the minimum version you can still complete on a difficult day."
        ),
        practice("practice.016",
            original("The next action should be too concrete to argue with."),
            "Which item on your list is still only a category?",
            "Rewrite it as one physical, observable action."
        ),
        practice("practice.017",
            original("The inbox can be empty while your real work remains untouched."),
            "What important work are small completions helping you avoid?",
            "Work on it for ten minutes before checking messages again."
        ),
        practice("practice.018",
            original("Confidence built before action is mostly imagination."),
            "What are you waiting to feel ready for?",
            "Take one reversible step while still uncertain."
        ),
        practice("practice.019",
            epictetus("Nothing great, said Epictetus, is produced suddenly, since not even the grape or the fig is.", "Discourses, What Philosophy Promises"),
            "What result are you demanding before its season?",
            "Do today's repetition and leave the outcome unmeasured until tomorrow."
        ),
        practice("practice.020",
            original("Later is a real choice with an invisible receipt."),
            "What will delay cost if repeated for a month?",
            "Pay two minutes toward it now instead."
        ),

        // Discipline
        practice("practice.021",
            original("Discipline is less about force than removing the next argument."),
            "Which useful choice do you renegotiate every day?",
            "Set one default that makes tomorrow's choice automatic."
        ),
        practice("practice.022",
            original("Missing once is weather. Missing twice is a route."),
            "What needs a gentle return today?",
            "Do the smallest complete version before bedtime."
        ),
        practice("practice.023",
            original("A standard you cannot practice on a bad day is a performance."),
            "What is the honest minimum for your hardest days?",
            "Define it in one sentence and practice it today."
        ),
        practice("practice.024",
            original("Make the right action easier before asking yourself to become stronger."),
            "What in your environment keeps voting against your intention?",
            "Move, block, or prepare one object so the better action becomes easier."
        ),
        practice("practice.025",
            original("If your system needs heroics, it is not a system yet."),
            "Where are you relying on last-minute effort?",
            "Add one checkpoint before the deadline."
        ),
        practice("practice.026",
            epictetus("Begin then from little things.", "Encheiridion, §12"),
            "What change have you rejected because the first version looked too small?",
            "Choose the smallest repetition that still counts and complete it."
        ),
        practice("practice.027",
            original("Measure the return, not the drift."),
            "How quickly do you return after attention, mood, or routine slips?",
            "Practice one immediate, unpunished return today."
        ),
        practice("practice.028",
            original("The promise after failure matters less than the environment changed before tomorrow."),
            "What made the last failure predictable?",
            "Change one condition before making another promise."
        ),
        practice("practice.029",
            original("What you repeat in private becomes your public limit."),
            "Which private repetition is lowering your standard?",
            "Interrupt it once today and record what triggered it."
        ),
        practice("practice.030",
            original("Rest that restores you is training. Escape that numbs you sends an invoice."),
            "Which kind of rest leaves you more available to life?",
            "Take ten minutes of that kind without a feed or notification."
        ),

        // Control and uncertainty
        practice("practice.031",
            epictetus("Of things some are in our power, and others are not.", "Encheiridion, §1"),
            "Which part of today's problem is actually yours to act on?",
            "Draw two columns—mine and not mine—then act on one item from the first."
        ),
        practice("practice.032",
            original("Worry rehearses pain, not response."),
            "What specific event are you worried about?",
            "Write one response you could take if it happens, then stop rehearsing it."
        ),
        practice("practice.033",
            original("Name the fact before you name the catastrophe."),
            "What do you know, and what have you added?",
            "Write the observable facts without predictions or motives."
        ),
        practice("practice.034",
            epictetus("Men are disturbed not by the things which happen, but by the opinions about the things.", "Encheiridion, §5"),
            "Which opinion is intensifying a difficult fact?",
            "Replace one absolute word—always, never, ruined—with a precise description."
        ),
        practice("practice.035",
            original("You cannot protect every option and still choose."),
            "Which decision stays open because closing doors feels like loss?",
            "Choose one reversible direction and give it a date for review."
        ),
        practice("practice.036",
            epictetus("Seek not that the things which happen should happen as you wish.", "Encheiridion, §8"),
            "What reality are you spending energy refusing?",
            "State it without approval or complaint, then choose your response."
        ),
        practice("practice.037",
            original("Certainty feels clean because it hides the unfinished work."),
            "Where are you more certain than your evidence allows?",
            "Write one fact that would change your mind."
        ),
        practice("practice.038",
            marcus("Nothing happens to any man which he is not formed by nature to bear.", "Book V, §18"),
            "Which capacity has a past difficulty already proven in you?",
            "Name that capacity and use it on the next ten minutes."
        ),
        practice("practice.039",
            original("A decision you revisit daily is a leak."),
            "Which settled choice keeps consuming fresh attention?",
            "Write a rule and a date when you are allowed to reconsider it."
        ),
        practice("practice.040",
            original("A day can fail its plan and still serve its purpose."),
            "What still matters now that today changed?",
            "Choose one useful act that fits the day you actually have."
        ),

        // Courage and avoidance
        practice("practice.041",
            original("Avoidance makes small doors look like walls."),
            "What has grown in your mind while remaining untouched?",
            "Approach it for five minutes without requiring completion."
        ),
        practice("practice.042",
            original("Courage is not volume. Sometimes it is one unedited sentence."),
            "What true sentence are you softening past recognition?",
            "Write it plainly; decide later whether it should be sent."
        ),
        practice("practice.043",
            epictetus("But let the thing wait for you.", "Encheiridion, §34"),
            "Which impulse gets stronger because you obey it immediately?",
            "Place a ten-minute delay between the impulse and the choice."
        ),
        practice("practice.044",
            original("You are allowed to disappoint the version of you that chose badly."),
            "Which old commitment survives only because changing feels inconsistent?",
            "Write what you know now that you did not know when you chose it."
        ),
        practice("practice.045",
            epictetus("But if it is right, why are you afraid of those who shall find fault wrongly?", "Encheiridion, §35"),
            "Which right action are you hiding to avoid being judged?",
            "Take one visible step without writing a defense for it."
        ),
        practice("practice.046",
            original("The life you want may be buried under commitments kept only to avoid awkwardness."),
            "Which commitment would you decline if it were offered today?",
            "Draft the respectful no, even if you do not send it yet."
        ),
        practice("practice.047",
            original("The fear of looking foolish has buried more practice than failure ever could."),
            "Where are you protecting competence instead of building it?",
            "Do one beginner repetition where the result can be imperfect."
        ),
        practice("practice.048",
            original("Comfort is useful for recovery and expensive as a compass."),
            "Which choice is being made by comfort alone?",
            "Add one small, deliberate discomfort that serves what matters."
        ),
        practice("practice.049",
            original("The honest answer usually appears before the impressive one."),
            "What was your first honest answer before you edited it?",
            "Write it in ten words without explaining yourself."
        ),
        practice("practice.050",
            marcus("A man then must stand erect, not be kept erect by others.", "Book III, §5"),
            "Where are you waiting for encouragement before acting?",
            "Begin one useful action without announcing it."
        ),

        // Truth and clear thinking
        practice("practice.051",
            original("Your strongest belief deserves your strongest test."),
            "Which belief is important enough to risk correcting?",
            "Find the strongest evidence against it and summarize it fairly."
        ),
        practice("practice.052",
            original("An opinion inherited unnoticed still directs your life."),
            "Which rule do you follow without remembering choosing it?",
            "Write whose rule it was and whether it still earns authority."
        ),
        practice("practice.053",
            original("Changing your mind is not losing when truth is the score."),
            "When did new evidence last change an important view?",
            "Name one current view you hold provisionally rather than permanently."
        ),
        practice("practice.054",
            original("The person you disagree with may be wrong; your summary of them can still be dishonest."),
            "Could they recognize their position in your description?",
            "Rewrite their case until they plausibly could."
        ),
        practice("practice.055",
            original("Speed hides questions that patience would force you to answer."),
            "Where are you rushing because stopping might change the plan?",
            "Pause for five minutes and write the question speed is hiding."
        ),
        practice("practice.056",
            marcus("Make for thyself a definition or description of the thing which is presented to thee.", "Book III, §11"),
            "What becomes clearer when stripped of its flattering or frightening label?",
            "Describe it using only observable details."
        ),
        practice("practice.057",
            original("You may be optimizing the part that is easiest to measure."),
            "Which metric looks good while the real outcome stays unchanged?",
            "Name one harder-to-measure sign of actual progress."
        ),
        practice("practice.058",
            original("The story you tell about yourself selects the evidence."),
            "Which self-story filters out contradictory facts?",
            "Record one true example that the story cannot comfortably explain."
        ),
        practice("practice.059",
            original("Read less. Argue with more of it."),
            "Which idea have you collected without testing?",
            "Write one objection and one practical consequence."
        ),
        practice("practice.060",
            original("Curiosity begins where the need to look informed ends."),
            "What would you ask if you were not protecting your image?",
            "Ask one basic question without apologizing for it."
        ),

        // Identity and standards
        practice("practice.061",
            original("Identity should explain your practice, not excuse it."),
            "Which label lets you avoid changing a behavior?",
            "Describe the behavior without using the label."
        ),
        practice("practice.062",
            original("Private standards are where character stops performing."),
            "What standard matters even when nobody can reward you?",
            "Keep one private promise today and do not announce it."
        ),
        practice("practice.063",
            original("Your values are easier to find in your refusals than in your bio."),
            "What deserves a no so a real value can receive a yes?",
            "Refuse, cancel, or reduce one low-value demand."
        ),
        practice("practice.064",
            epictetus("There is no limit to that which has once passed the true measure.", "Encheiridion, §39"),
            "Which role is consuming energy that belongs to work you can truly do?",
            "Reduce one promise to an honest, finishable scope."
        ),
        practice("practice.065",
            original("If the work matters only when witnessed, inspect the audience."),
            "Whose reaction has become part of your reason for doing this?",
            "Do ten minutes of the work with no plan to share the result."
        ),
        practice("practice.066",
            original("You are not your worst day, but you are responsible for the next move."),
            "What repair is available without turning failure into identity?",
            "Make the smallest repair before explaining what happened."
        ),
        practice("practice.067",
            original("A borrowed goal can consume an original life."),
            "Which goal sounds admirable but does not feel chosen?",
            "Write what you would pursue if nobody could compare the result."
        ),
        practice("practice.068",
            original("Self-respect grows from evidence, not affirmations."),
            "What promise would give you useful evidence today?",
            "Make it small enough to keep before the day ends."
        ),
        practice("practice.069",
            marcus("Never value anything as profitable to thyself which shall compel thee to break thy promise.", "Book III, §7"),
            "Which apparent advantage asks you to become someone you would not respect?",
            "Name the cost in character before deciding."
        ),
        practice("practice.070",
            original("Who you become is partly the cost you stop making others pay."),
            "Which of your patterns creates work, worry, or silence for someone else?",
            "Take responsibility for one part without adding a justification."
        ),

        // Relationships and boundaries
        practice("practice.071",
            original("A delayed no becomes a dishonest yes."),
            "Where is politeness creating a promise you cannot keep?",
            "Give one clear answer before resentment gives it for you."
        ),
        practice("practice.072",
            original("A boundary explained ten times is a negotiation."),
            "Which boundary needs enforcement rather than another argument?",
            "State the consequence once and follow through calmly."
        ),
        practice("practice.073",
            original("Being understood is not the same as being agreed with."),
            "Are you asking for comprehension or surrender?",
            "State your view once, then ask the other person to summarize it."
        ),
        practice("practice.074",
            original("Listen for the request underneath the complaint."),
            "What might this person need but not know how to ask for?",
            "Ask one clarifying question before offering a solution."
        ),
        practice("practice.075",
            original("The hardest conversation grows interest while you avoid it."),
            "What is getting more expensive because it remains unsaid?",
            "Write the opening sentence and choose a time for the conversation."
        ),
        practice("practice.076",
            original("Attention is one of the few gifts that cannot be given later."),
            "Who receives your proximity but not your presence?",
            "Give them ten minutes with every screen out of reach."
        ),
        practice("practice.077",
            original("Ask before helping; rescue can be control wearing kindness."),
            "Where might your help be replacing another person's choice?",
            "Ask what support they want before acting."
        ),
        practice("practice.078",
            original("An apology without changed logistics is a request to forget."),
            "What practical change would make your apology believable?",
            "Change the reminder, boundary, schedule, or system today."
        ),
        practice("practice.079",
            epictetus("Everything has two handles, the one by which it may be borne, the other by which it may not.", "Encheiridion, §43"),
            "Which interpretation of this conflict makes a useful response possible?",
            "Describe the same event from the most workable honest angle."
        ),
        practice("practice.080",
            original("You can leave room for someone without leaving yourself out."),
            "Where has care become self-erasure?",
            "Include one of your own needs in the next decision."
        ),

        // Learning and craft
        practice("practice.081",
            original("Learning that never changes a choice is storage."),
            "What have you learned but not used?",
            "Apply one idea to a real decision today."
        ),
        practice("practice.082",
            original("The note you take is not the lesson. The retrieval is."),
            "What could you explain without reopening the source?",
            "Close the source and write five points from memory."
        ),
        practice("practice.083",
            original("Practice exposes the questions that preparation keeps theoretical."),
            "What can only be learned by attempting it?",
            "Run one small trial and record where reality disagrees with your plan."
        ),
        practice("practice.084",
            original("Finishing teaches a different subject than starting."),
            "Which nearly finished piece of work could teach you about completion?",
            "Spend ten minutes on its final uncomfortable part."
        ),
        practice("practice.085",
            original("Feedback avoided becomes a ceiling chosen."),
            "Whose honest reaction could improve the work?",
            "Ask for one specific criticism, not general approval."
        ),
        practice("practice.086",
            original("A mistake studied once can pay rent for years."),
            "What did your last mistake reveal about the process?",
            "Write one prevention rule where you will see it next time."
        ),
        practice("practice.087",
            original("Clarity often arrives after subtraction, not addition."),
            "What can be removed without harming the essential result?",
            "Delete one step, feature, paragraph, or commitment."
        ),
        practice("practice.088",
            original("The draft is where taste stops being a spectator."),
            "What judgment are you making without producing anything to judge?",
            "Make an intentionally rough first version in ten minutes."
        ),
        practice("practice.089",
            original("Repetition without observation hardens mistakes."),
            "What do you repeat without checking whether it improves?",
            "Choose one detail to observe during today's repetition."
        ),
        practice("practice.090",
            original("The useful question is often the one that changes the work, not the one that displays knowledge."),
            "Which question would alter what you do next?",
            "Answer it with a test, not another opinion."
        ),

        // Time and direction
        practice("practice.091",
            original("Time is not only spent. It is traded for a particular self."),
            "Who are your repeated hours training you to become?",
            "Trade ten minutes from a default activity to a chosen one."
        ),
        practice("practice.092",
            original("A year changes at the level of ordinary Tuesdays."),
            "What ordinary-day behavior would make the year different?",
            "Practice it once today at a time you can repeat next week."
        ),
        practice("practice.093",
            marcus("Bear in mind that every man lives only this present time.", "Book III, §10"),
            "What deserves the present hour rather than a vague future promise?",
            "Choose one thing and give it the next uninterrupted ten minutes."
        ),
        practice("practice.094",
            original("A goal without a subtraction is a wish for extra hours."),
            "What will receive less time if this goal is real?",
            "Remove one recurring activity from the calendar."
        ),
        practice("practice.095",
            original("The deadline is not the only thing making this moment finite."),
            "What are you postponing as if the opportunity were permanent?",
            "Take one step while the person, health, access, or season is still here."
        ),
        practice("practice.096",
            original("Some seasons are for expansion; others are for keeping one promise alive."),
            "What season are you actually in?",
            "Choose the one promise that must survive this week."
        ),
        practice("practice.097",
            marcus("Do not disturb thyself by thinking of the whole of thy life.", "Book VIII, §36"),
            "Which imagined future is making the present task heavier?",
            "Reduce the horizon to what can be handled in the next ten minutes."
        ),
        practice("practice.098",
            original("You do not owe every hour productivity; you owe important hours honesty."),
            "Is this hour for work, rest, or avoidance?",
            "Name it truthfully and do that one thing without mixing the others into it."
        ),
        practice("practice.099",
            original("Before adding a goal, decide what will receive less life."),
            "Which existing commitment must shrink for the new one to fit?",
            "Write the tradeoff beside the goal before accepting it."
        ),
        practice("practice.100",
            original("End the day by reducing tomorrow's first decision."),
            "What choice could your tired evening self make for your morning self?",
            "Prepare the first task, tool, and starting time before bed."
        ),
    ]

    // Legacy prose and unversioned localization keys are immutable v1 archives.
    private static let revisedPractices: [DailyPractice] = [
        practice("practice.002", original("Give your attention a little distance from what keeps asking for it."),
                 "Where would a little distance help you be present?",
                 "Move one distraction out of reach for a few minutes, if that works for you.", version: 2),
        practice("practice.013", original("On a difficult day, let the first step be smaller."),
                 "What small start fits the energy you have today?",
                 "Try a two-minute start, or write the first step for when you are ready.", version: 2),
        practice("practice.022", original("A missed day leaves the next step available."),
                 "What would a gentle return look like for you?",
                 "Choose one small step you can return to, without making up for missed days.", version: 2),
        practice("practice.023", original("Give your hardest days a gentler version of the plan."),
                 "What could you reduce when the full plan asks too much?",
                 "Write a smaller version of one plan, including permission to pause.", version: 2),
        practice("practice.030", original("Notice which kind of rest leaves you feeling more like yourself."),
                 "What kind of rest would feel welcome today?",
                 "Make room for a little rest you choose. It does not have to earn its place.", version: 2),
        practice("practice.032", original("When worry circles, look for one response you can prepare."),
                 "Is there something useful you can prepare for?",
                 "Write one possible response. If nothing needs action now, leave the note for later.", version: 2),
        practice("practice.064", epictetus("There is no limit to that which has once passed the true measure.", "Encheiridion, §39"),
                 "What would enough look like for one possession you want?",
                 "Write what it needs to do for you, then set a limit before looking for more.", version: 2),
        practice("practice.068", original("A small promise kept can help you trust yourself again."),
                 "What kind promise to yourself feels possible today?",
                 "Choose a small promise you can keep or revise with care if your needs change.", version: 2),
        practice("practice.082", original("Try recalling one idea before reopening your notes."),
                 "Which idea would you like to understand a little better?",
                 "Write one idea from memory, then check your notes and add what you missed.", version: 2),
        practice("practice.094", original("A quiet moment can belong to you without becoming a goal."),
                 "Where could you leave a little time unplanned?",
                 "Leave five minutes open today and decide in that moment how to spend them.", version: 2),
    ]

    private static let addedPractices: [DailyPractice] = [
        practice("practice.101", original("You can pause without giving up your direction."),
                 "What needs a pause rather than another push?",
                 "Take five quiet minutes, then decide what still needs doing."),
        practice("practice.102", original("Enough is a decision you can make before you are exhausted."),
                 "What would enough look like today?",
                 "Write a stopping point for one task and honor it."),
        practice("practice.103", original("Let one useful thing you did count before you plan the next."),
                 "What helped today, even a little?",
                 "Name it in one sentence without adding a criticism."),
        practice("practice.104", original("A small question can make room for someone else's whole day."),
                 "Who have you been meaning to check in with?",
                 "Ask how they are, then give the answer your full attention."),
        practice("practice.105", original("Leave room between what happened and what it means."),
                 "What meaning did you add to today's hardest moment?",
                 "Write the event and your interpretation on separate lines."),
        practice("practice.106", original("Keep one question open long enough to learn something."),
                 "Which question have you answered too quickly?",
                 "Write two possible answers before choosing a next step."),
        practice("practice.107", original("A clear limit can protect something you want to keep."),
                 "What would a small boundary make possible?",
                 "Name one limit and the time or energy it protects."),
        practice("practice.108", original("Make a little room for something that does not need to be useful."),
                 "What would you enjoy without needing to improve at it?",
                 "Spend ten minutes with it and leave the result unmeasured."),
    ]

    /// Frozen schedule contracts. Never append to these arrays: introduce a new
    /// version and future cutover instead. Catalog insertion/reordering is harmless.
    static let legacyScheduleIDs: [String] = [
        "practice.001", "practice.002", "practice.003", "practice.004", "practice.005", "practice.006", "practice.007", "practice.008", "practice.009", "practice.010", "practice.011", "practice.012", "practice.013", "practice.014", "practice.015", "practice.016", "practice.017", "practice.018", "practice.019", "practice.020", "practice.021", "practice.022", "practice.023", "practice.024", "practice.025", "practice.026", "practice.027", "practice.028", "practice.029", "practice.030", "practice.031", "practice.032", "practice.033", "practice.034", "practice.035", "practice.036", "practice.037", "practice.038", "practice.039", "practice.040", "practice.041", "practice.042", "practice.043", "practice.044", "practice.045", "practice.046", "practice.047", "practice.048", "practice.049", "practice.050", "practice.051", "practice.052", "practice.053", "practice.054", "practice.055", "practice.056", "practice.057", "practice.058", "practice.059", "practice.060", "practice.061", "practice.062", "practice.063", "practice.064", "practice.065", "practice.066", "practice.067", "practice.068", "practice.069", "practice.070", "practice.071", "practice.072", "practice.073", "practice.074", "practice.075", "practice.076", "practice.077", "practice.078", "practice.079", "practice.080", "practice.081", "practice.082", "practice.083", "practice.084", "practice.085", "practice.086", "practice.087", "practice.088", "practice.089", "practice.090", "practice.091", "practice.092", "practice.093", "practice.094", "practice.095", "practice.096", "practice.097", "practice.098", "practice.099", "practice.100"
    ]
    static let editorialScheduleIDs: [String] = [
        "practice.001", "practice.011", "practice.021", "practice.031", "practice.041", "practice.051", "practice.061", "practice.071", "practice.081", "practice.091",
        "practice.101", "practice.002", "practice.012", "practice.022", "practice.032", "practice.042", "practice.052", "practice.062", "practice.072", "practice.082",
        "practice.092", "practice.102", "practice.003", "practice.013", "practice.023", "practice.033", "practice.043", "practice.053", "practice.063", "practice.073",
        "practice.083", "practice.093", "practice.103", "practice.004", "practice.014", "practice.024", "practice.034", "practice.044", "practice.054", "practice.064",
        "practice.074", "practice.084", "practice.094", "practice.104", "practice.005", "practice.015", "practice.025", "practice.035", "practice.045", "practice.055",
        "practice.065", "practice.075", "practice.085", "practice.095", "practice.105", "practice.006", "practice.016", "practice.026", "practice.036", "practice.046",
        "practice.056", "practice.066", "practice.076", "practice.086", "practice.096", "practice.106", "practice.007", "practice.017", "practice.027", "practice.037",
        "practice.047", "practice.057", "practice.067", "practice.077", "practice.087", "practice.097", "practice.107", "practice.008", "practice.018", "practice.028",
        "practice.048", "practice.058", "practice.068", "practice.078", "practice.088", "practice.098", "practice.108", "practice.009", "practice.019", "practice.029",
        "practice.039", "practice.049", "practice.059", "practice.069", "practice.079", "practice.089", "practice.099", "practice.010", "practice.020", "practice.030",
        "practice.040", "practice.050", "practice.060", "practice.070", "practice.080", "practice.090", "practice.100",
    ]
    static let scheduleCutoverDay = "2026-10-01"

    private static var latestSources: [DailyPractice] {
        sourcePractices.map { source in
            revisedPractices.first { $0.id == source.id } ?? source
        } + addedPractices
    }

    static let practices = latestSources.map { localized($0) }
    static let quotes = practices.map(\.quote)
    static let questions = practices.map(\.question)
    static let actions = practices.map(\.action)

    /// A nil version selects the current editorial revision; v1 always recovers
    /// the original wording, including withdrawn daily-schedule practice.038.
    static func practice(id: String, version: Int? = nil, locale: Locale? = nil) -> DailyPractice? {
        let candidates = sourcePractices + revisedPractices + addedPractices
        let matching = candidates.filter { $0.id == id && (version == nil || $0.version == version) }
        guard let source = matching.max(by: { $0.version < $1.version }) else { return nil }
        return localized(source, locale: locale)
    }

    static func suggestions(for preference: PracticePreference) -> [DailyPractice] {
        practices.filter { practice in
            (preference.theme == nil || practice.tags.contains(preference.theme!))
                && (preference.maximumMinutes == nil || practice.estimatedMinutes <= preference.maximumMinutes!)
                && practice.id != "practice.038"
        }
    }

    static func dailyPractice(
        for date: Date = .now,
        calendar: Calendar = .current
    ) -> DailyPractice {
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = calendar.timeZone
        let cutover = civil.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        if date < cutover {
            let id = legacyScheduleIDs[dayNumber(for: date, calendar: calendar) % 100]
            return practice(id: id, version: 1)!
        }
        let days = civil.dateComponents([.day], from: cutover, to: civil.startOfDay(for: date)).day ?? 0
        let id = editorialScheduleIDs[days % 107]
        // Freeze revisions as part of v2; future revisions require a new schedule.
        let version = revisedPractices.contains { $0.id == id } ? 2 : 1
        return practice(id: id, version: version)!
    }

    private static func localized(_ source: DailyPractice, locale: Locale? = nil) -> DailyPractice {
        let key = source.version == 1 ? source.id : "\(source.id).v\(source.version)"
        return DailyPractice(
            quote: Quote(
                text: localizedContent("\(key).line", fallback: source.quote.text, locale: locale),
                author: localizedContent("\(source.id).author", fallback: source.quote.author, locale: locale),
                source: source.quote.source,
                localizationKey: source.id
            ),
            question: localizedContent("\(key).question", fallback: source.question, locale: locale),
            action: localizedContent("\(key).action", fallback: source.action, locale: locale),
            version: source.version, tags: source.tags, estimatedMinutes: source.estimatedMinutes
        )
    }

    static func dailyQuote(
        for date: Date = .now,
        calendar: Calendar = .current
    ) -> Quote {
        dailyPractice(for: date, calendar: calendar).quote
    }

    static func dailyQuestion(
        for date: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        dailyPractice(for: date, calendar: calendar).question
    }

    static func dailyAction(
        for date: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        dailyPractice(for: date, calendar: calendar).action
    }

    private static func practice(
        _ id: String,
        _ quote: Quote,
        _ question: String,
        _ action: String,
        version: Int = 1
    ) -> DailyPractice {
        DailyPractice(
            quote: Quote(text: quote.text, author: quote.author, source: quote.source, localizationKey: id),
            question: question, action: action, version: version,
            tags: [theme(for: id)], estimatedMinutes: id == "practice.108" ? 10 : 5
        )
    }

    private static func theme(for id: String) -> PracticeTheme {
        let number = Int(id.split(separator: ".").last ?? "") ?? 0
        switch number {
        case 1...10: return .focus
        case 11...20: return .action
        case 21...29: return .consistency
        case 30, 94, 101: return .recovery
        case 31...40, 51...60, 105: return .clarity
        case 41...50: return .courage
        case 64, 102: return .enough
        case 61...70: return .identity
        case 71...80, 104: return .connection
        case 81...90: return .learning
        case 91...100: return .direction
        case 103: return .kindness
        case 106: return .curiosity
        case 107: return .boundaries
        case 108: return .joy
        default: return .clarity
        }
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

    private static func localizedContent(_ key: String, fallback: String, locale: Locale? = nil) -> String {
        guard let locale else {
            return Bundle.main.localizedString(forKey: key, value: fallback, table: "Content")
        }
        let language = locale.language.languageCode?.identifier ?? "en"
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let candidates = [identifier, language == "pt" ? "pt-BR" : language, "en"]
        for candidate in candidates {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle.localizedString(forKey: key, value: fallback, table: "Content")
            }
        }
        return fallback
    }

    /// Calendar-based day ordinal. Seconds math repeats or skips local days at
    /// daylight-saving transitions.
    private static func dayNumber(for date: Date, calendar: Calendar) -> Int {
        let reference = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let day = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: reference, to: day).day ?? 0)
    }
}
