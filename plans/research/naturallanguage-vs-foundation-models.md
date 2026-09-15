# NaturalLanguage versus Foundation Models for mood suggestion and theme tagging

- **Ticket**: wayfinder research #60 (part of #58)
- **Date**: 2026-09-15
- **Scope**: two classification jobs on short private journal text in Think (iOS 26.0 deployment target; locales en, bg, de, es, fr, it, pt-BR):
  - (a) suggest one of five fixed moods (`low`, `flat`, `steady`, `good`, `sharp`, see `plans/010-mood-tag.md`);
  - (b) label an entry with a handful of themes from a fixed set of at least five or six labels.
- **Sources**: Apple developer documentation, WWDC session transcripts, Apple Support, Apple Newsroom, Apple Machine Learning Research. Where the documentation is silent, a runtime probe on this Mac (macOS 27.0, build 26A428) is reported and labelled as such. Anything not backed by one of those is marked **Unverified**.

## 1. What is shipping today

iOS 27.0 (24A437), iPadOS 27.0, macOS 27.0 and Xcode 27 were released on 2026-09-14 ([developer.apple.com/news/releases](https://developer.apple.com/news/releases/)). Think's deployment target is iOS 26.0, so users will be on 26.x or 27.x. Apple states that the on-device Foundation Model has three versions so far, aligned with iOS 26.0–26.3, iOS 26.4 and iOS 27.0, and that prompts should be re-tested per model version ([SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel), [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)).

## 2. NaturalLanguage framework

### 2.1 Availability and device eligibility

- The Natural Language framework is available from iOS 12.0 with no hardware restriction stated ([Natural Language](https://developer.apple.com/documentation/naturallanguage)). Sub-APIs: `NLTagScheme.sentimentScore` iOS 13.0 ([sentimentScore](https://developer.apple.com/documentation/naturallanguage/nltagscheme/sentimentscore)); `NLEmbedding` iOS 13.0, `sentenceEmbedding(for:)` iOS 14.0 ([NLEmbedding](https://developer.apple.com/documentation/naturallanguage/nlembedding), [sentenceEmbedding(for:)](https://developer.apple.com/documentation/naturallanguage/nlembedding/sentenceembedding(for:))); `NLContextualEmbedding` iOS 17.0 ([NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding)); `NLModel` iOS 12.0 and `predictedLabelHypotheses(for:maximumCount:)` iOS 14.0 ([NLModel](https://developer.apple.com/documentation/naturallanguage/nlmodel), [predictedLabelHypotheses](https://developer.apple.com/documentation/naturallanguage/nlmodel/predictedlabelhypotheses(for:maximumcount:))).
- Confirmed: every iPhone that runs iOS 26 satisfies these minimums, and none of the pages lists an Apple Intelligence or chip requirement. What is gated is **language assets**, not hardware: Apple ships language assets on demand and says "for users of our applications, we make sure that they always have the assets in the language they're interested in" ([WWDC19 session 232](https://developer.apple.com/videos/play/wwdc2019/232/)). `NLContextualEmbedding` exposes this explicitly with `hasAvailableAssets` and `requestAssets(completionHandler:)` ([NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding)).
- Everything runs on device: "all of this is happening completely on device, and the user data never has to leave the device" ([WWDC19 session 232](https://developer.apple.com/videos/play/wwdc2019/232/)).

### 2.2 Language coverage per API

| API | Documented languages | Bulgarian | Think locales covered | Source |
|---|---|---|---|---|
| `NLTagger` sentiment score | English, French, Italian, German, Spanish, Portuguese, Simplified Chinese (7) | No | 6 of 7 (all but bg) | [WWDC19 232](https://developer.apple.com/videos/play/wwdc2019/232/) |
| `NLEmbedding` word embeddings | Same 7 | No | 6 of 7 | [WWDC19 232](https://developer.apple.com/videos/play/wwdc2019/232/) |
| `NLEmbedding` sentence embeddings (512-dim) | English, Spanish, French, German, Italian, Portuguese, Simplified Chinese (7) | No | 6 of 7 | [WWDC20 10657](https://developer.apple.com/videos/play/wwdc2020/10657/) |
| `NLContextualEmbedding` (BERT, used by Create ML `.bertEmbedding`) | 27 languages across three script models: Latin, Cyrillic, CJK | Yes (Cyrillic model, see probe) | 7 of 7 | [WWDC23 10042](https://developer.apple.com/videos/play/wwdc2023/10042/), [NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding) |
| Create ML transfer learning with static or ELMo embeddings | "the same languages as static embeddings and sentence embeddings" (7) | No | 6 of 7 | [WWDC20 10657](https://developer.apple.com/videos/play/wwdc2020/10657/) |
| Create ML `maxEnt` | Any language (word-frequency model, no pretrained assets); Apple recommends it for multilingual data | Yes | 7 of 7 | [Creating a text classifier model](https://developer.apple.com/documentation/createml/creating-a-text-classifier-model) |

Apple's reference pages do not enumerate the sentiment or embedding languages; the lists above come from the WWDC transcripts. The reference pages give the runtime checks instead: `NLTagger.availableTagSchemes(for:language:)` ([doc](https://developer.apple.com/documentation/naturallanguage/nltagger/availabletagschemes(for:language:))), `NLEmbedding.supportedRevisions(for:)` and `supportedSentenceEmbeddingRevisions(for:)` ([doc](https://developer.apple.com/documentation/naturallanguage/nlembedding/supportedrevisions(for:))), and `wordEmbedding(for:)` / `sentenceEmbedding(for:)` returning `nil` when unavailable.

**Runtime probe (macOS 27.0, build 26A428, this Mac; not an iOS measurement)** using those checks:

- Bulgarian: `availableTagSchemes(for: .paragraph, language: .bulgarian)` does not contain `.sentimentScore`; `supportedRevisions(for: .bulgarian)` and `supportedSentenceEmbeddingRevisions(for: .bulgarian)` are both empty; `wordEmbedding(for:)` and `sentenceEmbedding(for:)` return `nil`. `NLContextualEmbedding(language: .bulgarian)` returns the Cyrillic model (languages `bg, uk, ru, kk`, dimension 512, `maximumSequenceLength` 256) with `hasAvailableAssets == false`, so the Cyrillic assets must be downloaded via `requestAssets` before first use.
- de, es, fr, it: `supportedRevisions` returns `[1]` for word and sentence embeddings (the framework supports them), but on this Mac the embeddings returned `nil` and the sentiment scheme was not listed, because the assets for those languages are not installed here. On iOS the assets follow the user's language settings (WWDC19 quote above), but this is the mechanism by which a NaturalLanguage feature can silently be unavailable for a given user; the app must check at runtime and not assume.
- The Latin-script contextual model lists `cs, da, de, en, es, fi, fr, hr, hu, id, it, nb, nl, pl, pt, ro, sk, sv, tr, vi` (20 languages) and covers all six Latin-script Think locales in one model.
- Calling the sentiment tagger on a clearly negative Bulgarian sentence returned `0.8` rather than `nil`; the API does not refuse unsupported languages, it returns a meaningless score. Any sentiment use must gate on `availableTagSchemes` first.

### 2.3 Sentiment scoring (NLTagger)

- Score range `[-1.0, 1.0]`, requested at `.paragraph` or `.sentence` unit ([sentimentScore](https://developer.apple.com/documentation/naturallanguage/nltagscheme/sentimentscore); [WWDC19 232](https://developer.apple.com/videos/play/wwdc2019/232/)).
- It is a single valence axis; Apple says "we provide the score and let you calibrate the score for your application" ([WWDC19 232](https://developer.apple.com/videos/play/wwdc2019/232/)). It cannot separate the five Think moods by itself: `good` versus `sharp` and `low` versus `flat` are not distinguishable on one positive-negative axis. There is no label set and no confidence; the score itself is the only signal.
- Cost: "It uses a Neural Network model underneath, and it's hardware activated across all Apple platforms, so essentially, you can do this in real time" ([WWDC19 232](https://developer.apple.com/videos/play/wwdc2019/232/)). No latency figures or model sizes are published. **Unverified**: exact latency.

### 2.4 Embeddings (NLEmbedding, NLContextualEmbedding)

- `NLEmbedding` gives word vectors, sentence vectors, distances and nearest neighbours; sentence embeddings "don't have a fixed vocabulary, and they can return results for arbitrary sentences" but do not support nearest-neighbour search ([Finding similarities between pieces of text](https://developer.apple.com/documentation/naturallanguage/finding-similarities-between-pieces-of-text)). One `NLEmbedding` instance is not safe for concurrent use ([NLEmbedding](https://developer.apple.com/documentation/naturallanguage/nlembedding)).
- Custom embeddings compiled through Create ML `MLWordEmbedding` shrink to "tens of megabytes" and answer nearest-neighbour queries "in just a couple of milliseconds" ([WWDC19 232](https://developer.apple.com/videos/play/wwdc2019/232/)). This is the only published inference-cost figure for NaturalLanguage.
- `NLContextualEmbedding` returns per-token vector sequences (not one sentence vector) and is intended as the input layer for Create ML text classifiers (`.bertEmbedding`) or for models you train in PyTorch/TensorFlow and convert with Core ML Tools ([NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding); [WWDC23 10042](https://developer.apple.com/videos/play/wwdc2023/10042/)).
- Fixed label set with embeddings: an embedding-only approach would compare the entry vector against per-label prototype vectors and threshold on cosine distance. Apple documents the distance API but not a classification recipe; quality on five subtle mood labels is **Unverified**. Bulgarian has no sentence embedding, so this route covers 6 of 7 locales unless mean-pooled contextual vectors are used (**Unverified** quality).

### 2.5 Custom classifier (Create ML `MLTextClassifier` + `NLModel`)

- Training happens on the developer's Mac (Create ML app or the CreateML framework, macOS 10.14+) from labelled text in JSON, CSV or folder-per-label form; the result is a `.mlmodel` you drag into Xcode and load through `NLModel` so tokenisation matches training ([Creating a text classifier model](https://developer.apple.com/documentation/createml/creating-a-text-classifier-model); [MLTextClassifier](https://developer.apple.com/documentation/createml/mltextclassifier)). No user data is involved in training unless the developer collects it; inference runs on device through `NLModel` ([NLModel](https://developer.apple.com/documentation/naturallanguage/nlmodel)). Confirmed: a developer-trained, bundled classifier with no user data leaving the device is the documented path.
- Algorithms: `maxEnt` (multinomial logistic regression on word frequencies, fastest to train), `crf`, and `transferLearning(_:revision:)` with feature extractors `staticEmbedding`, `elmoEmbedding`, `bertEmbedding`, `dynamicEmbedding`, `customEmbedding` ([ModelAlgorithmType](https://developer.apple.com/documentation/createml/mltextclassifier/modelalgorithmtype), [FeatureExtractorType](https://developer.apple.com/documentation/createml/mltextclassifier/featureextractortype)). Apple's guidance: "If your data contains multiple languages, choose either the maximum entropy algorithm or the transfer learning algorithm and set its FeatureExtractorType to the BERT embedding feature extractor. If your data contains a single language, use the CRF algorithm or the transfer learning algorithm with the ELMo feature extractor" ([Creating a text classifier model](https://developer.apple.com/documentation/createml/creating-a-text-classifier-model)).
- Language constraints: BERT transfer learning spans 27 languages in three script groups; the Create ML app asks for the script (Latin, Cyrillic, CJK) or a single language; Apple recommends "training data for each of the languages you are interested in", while noting some cross-language transfer ([WWDC23 10042](https://developer.apple.com/videos/play/wwdc2023/10042/)). **Unverified**: whether a single `MLTextClassifier` can be trained across two script models (Latin for en/de/es/fr/it/pt-BR and Cyrillic for bg) or whether Think would need one Latin and one Cyrillic model. The demo in WWDC23 picks one script per model.
- Training volume: Apple publishes no minimum. The WWDC19 demo trained a 14-class classifier on 200 examples total; `maxEnt` reached 77% and transfer learning with dynamic embeddings 86.5% on the test set, with the data balanced across classes and separate validation and test sets ([WWDC19 232](https://developer.apple.com/videos/play/wwdc2019/232/)). Apple's data advice: match the training text to what the app will see in practice (fragments, full sentences, etc.) and cover the variation ([WWDC19 232](https://developer.apple.com/videos/play/wwdc2019/232/)). WWDC23 frames BERT transfer learning as letting you "train with less data" ([WWDC23 10042](https://developer.apple.com/videos/play/wwdc2023/10042/)). Practical reading: a few hundred labelled short entries per mood, per language, is the order of magnitude the demos use; **Unverified** for Think's exact labels.
- Fixed label set: the label set is exactly the set of labels in the training data; the model cannot emit anything else. `predictedLabel(for:)` returns the top label, and `predictedLabelHypotheses(for:maximumCount:)` returns "a dictionary of label hypotheses. Each dictionary entry is a predicted label with its associated probability score" ([predictedLabelHypotheses](https://developer.apple.com/documentation/naturallanguage/nlmodel/predictedlabelhypotheses(for:maximumcount:))). Create ML exposes the same during evaluation via `predictionWithConfidence(from:)` ([MLTextClassifier](https://developer.apple.com/documentation/createml/mltextclassifier)).
- Confidence threshold: Apple's guidance is to "avoid heuristic hard coding of these threshold values and calibrate it on representative data" and to set "thresholds on a per class basis rather than setting a global threshold" ([WWDC20 10657](https://developer.apple.com/videos/play/wwdc2020/10657/)).
- Multi-label (job b): `MLTextClassifier` is single-label per input. Multi-label theme tagging is achievable either by taking the top-k hypotheses above per-class thresholds from one classifier, or by training one binary classifier per theme. Neither is documented by Apple as a pattern; both are ordinary uses of the documented API. **Unverified**: which performs better on journal text.
- Cost: no model size or latency figures are published for Create ML text classifiers. `maxEnt` models are word-frequency models; transfer-learning models depend on the on-device BERT/ELMo assets rather than embedding them, which is why the contextual assets are downloaded separately ([NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding)). **Unverified**: bundle size and per-call latency.
- Side note: `MLTextClassifier` lists iOS 15.0 availability ([MLTextClassifier](https://developer.apple.com/documentation/createml/mltextclassifier)), so on-device retraining is technically possible; this document does not rely on it.

## 3. Foundation Models framework

### 3.1 Availability and device eligibility

- iOS 26.0+; "To use Apple Foundation Models, people need a device that supports Apple Intelligence" ([Foundation Models](https://developer.apple.com/documentation/foundationmodels)). `SystemLanguageModel.availability` reports `.available` or `.unavailable(reason)` with reasons `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady` ([UnavailableReason](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason)).
- Apple Intelligence device list (support article, now describing the 27.0 releases): iPhone 16 models or later, iPhone 15 Pro, iPhone 15 Pro Max, iPhone Air, plus listed iPads, Macs, Vision Pro and Watches; requires up to 8 GB of storage on most iPhones (up to 14 GB on iPhone 17 Pro / Pro Max / Air); "Device language and Siri language set to the same supported language" ([support.apple.com/121115](https://support.apple.com/121115)). Every iPhone below the 15 Pro is excluded even though it runs iOS 26.

### 3.2 Language coverage

- Apple Intelligence languages: English, Danish, Dutch, French, German, Italian, Norwegian, Portuguese, Spanish, Swedish, Turkish, Vietnamese, Chinese (simplified), Chinese (traditional), Japanese, Korean ([support.apple.com/121115](https://support.apple.com/121115)). Bulgarian is not supported. For the iOS 26 cycle Apple announced the eight additions (Danish, Dutch, Norwegian, Portuguese (Portugal), Swedish, Turkish, Chinese (traditional), Vietnamese) as "coming soon" on 2025-09-15 ([Apple Newsroom](https://www.apple.com/newsroom/2025/09/new-apple-intelligence-features-are-available-today/)); **Unverified** which 26.x point release delivered them.
- The model is multilingual and the same model handles prompts, instructions and output in any supported language; check `SystemLanguageModel.default.supportsLocale()` before calling; the framework detects input language and "If the model detects a language it doesn't support, the session throws `unsupportedLanguageOrLocale`"; guardrails only operate for supported languages ([Supporting languages and locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)). Apple also warns the response quality improves if instructions include "The person's locale is <identifier>." for non-US-English locales (same page). Think's Bulgarian users would therefore get an error, not a degraded result.

### 3.3 Model, context and inference cost

- On-device model: "a large language model with 3 billion parameters, each quantized to 2 bits" ([WWDC25 286](https://developer.apple.com/videos/play/wwdc2025/286/)); "a ~3B-parameter on-device model optimized for Apple silicon through ... 2-bit quantization-aware training" ([Apple Intelligence Foundation Language Models Tech Report 2025](https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025)). The model ships with the OS, not the app; the app bundle grows by nothing.
- Context window: 4096 tokens per session, shared by instructions, prompt, `Generable` schemas, tool definitions and responses; roughly 3–4 characters per token in Latin-script languages ([Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)). Short journal entries fit comfortably.
- Latency: Apple states that "large language models take longer to run compared to traditional ML models", that the model may have to be loaded from storage before a request ("Model Loading" track in Instruments), and offers `prewarm` to load it ahead of time ([WWDC25 286](https://developer.apple.com/videos/play/wwdc2025/286/); [WWDC25 259](https://developer.apple.com/videos/play/wwdc2025/259/); [Analyzing the runtime performance](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app)). Guided generation "allows us to perform optimizations that speed up inference" ([WWDC25 286](https://developer.apple.com/videos/play/wwdc2025/286/)). No numeric latency is published. **Unverified**: per-request latency on iPhone 15 Pro/16.
- Apple positions the on-device model for "summarization, extraction, classification" and says it "is not suitable for world knowledge or advanced reasoning" ([WWDC25 286](https://developer.apple.com/videos/play/wwdc2025/286/)).

### 3.4 Fixed label set via guided generation

- `@Generable` applies to "your Swift structure or enumeration"; the framework "uses constrained sampling when generating output", which "prevents the model from producing malformed output and provides you with results as a type you define" ([Generable](https://developer.apple.com/documentation/foundationmodels/generable); [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)). The WWDC25 code-along generates an enum of categories the same way ([WWDC25 259](https://developer.apple.com/videos/play/wwdc2025/259/)). Confirmed: a `@Generable enum Mood` with five cases, or a `@Generable struct` with `@Guide(.anyOf([...]))` on a `String`, constrains the model to the fixed set; `GenerationGuide.anyOf(_:)` "Enforces that the string be one of the provided values" ([anyOf](https://developer.apple.com/documentation/foundationmodels/generationguide/anyof(_:))). For a runtime-defined set, `DynamicGenerationSchema(name:anyOf:)` does the same ([guided generation article](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)).
- Multi-label themes: an array property with `@Guide(.maximumCount(n))` (and `.minimumCount`, `.count`) bounds the number of labels ([GenerationGuide](https://developer.apple.com/documentation/foundationmodels/generationguide)); element guides via `.element(_:)`. Each `Generable` type is turned into a JSON schema and consumes context tokens ([Generable](https://developer.apple.com/documentation/foundationmodels/generable)).
- `SystemLanguageModel(useCase: .contentTagging)` is a specialised variant that "always responds with tags" for topics, emotions, actions and objects, producing "one to a few lowercase words" per tag; Apple recommends topic and emotion tagging for very short input, and says "If you have a complex set of constraints on tagging that are more complicated than the maximum count support of the tagging model, use general instead" ([Categorizing and organizing data with content tags](https://developer.apple.com/documentation/foundationmodels/categorizing-and-organizing-data-with-content-tags); [contentTagging](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase/contenttagging)). It is an open-vocabulary tagger; mapping its output onto Think's fixed theme set would need a second step (string matching or a second guided-generation call).

### 3.5 Confidence

- No API returns a probability or confidence. `LanguageModelSession.Response` exposes `content`, `rawContent`, `usage` (token counts) and `transcriptEntries` only ([Response](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/response)). `GenerationOptions` controls decoding (`temperature` 0–1, `SamplingMode.greedy`, `.random(top:seed:)`, `.random(probabilityThreshold:seed:)`) but does not surface the distribution ([GenerationOptions](https://developer.apple.com/documentation/foundationmodels/generationoptions); [SamplingMode](https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct)). Greedy sampling "always produces the same output for a given input" ([greedy](https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct/greedy)), which gives determinism but still no score.
- Workarounds Apple does not document (**Unverified** in effect): ask the model for a self-reported confidence field (a generated number, not a calibrated probability), or provide an explicit `unsure`/`none` enum case so the model can abstain.

### 3.6 Safety behaviour relevant to journals

- Guardrails check both prompt and output and "aim to block harmful or sensitive content, such as self-harm, violence, and adult materials"; a hit throws `guardrailViolation`, and the model may additionally throw `refusal` under guided generation ([Improving the safety of generative model output](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output); [GenerationError](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror)). The `permissiveContentTransformations` guardrail mode applies only to `String` output: "When you generate responses other than String, this mode behaves the same way as default mode and throws guardrailViolation errors" ([permissiveContentTransformations](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations)). For a journal, the entries most likely to be tagged `low` are exactly the ones most likely to trip the guardrail, and the fixed-enum path cannot opt out. Apple lists "improved guardrails" that reduce blocking of benign content in iOS 26.4 ([Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)); the residual rate is **Unverified**.
- Other runtime errors to handle: `rateLimited`, `exceededContextWindowSize`, `assetsUnavailable`, `unsupportedLanguageOrLocale` ([GenerationError](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror)).

## 4. Side-by-side summary

| Question | NaturalLanguage (sentiment / embeddings / Create ML + NLModel) | Foundation Models (iOS 26+) |
|---|---|---|
| Runs on every iPhone on iOS 26 | Yes (iOS 12–17 minimums, no hardware gate); language assets may need download | No: Apple Intelligence devices only (iPhone 15 Pro/Pro Max, 16+, Air), Apple Intelligence enabled, matching device and Siri language |
| Bulgarian | Sentiment, word and sentence embeddings: no. Contextual BERT embeddings and Create ML BERT/maxEnt classifiers: yes | No (16 supported languages, none Cyrillic); throws `unsupportedLanguageOrLocale` |
| Other six Think locales | Yes for all APIs | Yes (en, de, es, fr, it, pt) |
| Developer-trained, bundled model, no user data leaves device | Yes, documented path (Create ML on Mac, `.mlmodel` in bundle, `NLModel` on device) | Not applicable (system model, no training); inference is on device |
| Training data needed | Yes, developer-labelled; Apple demos use ~200 examples for 14 classes with transfer learning; no minimum published | None |
| Fixed label set | Exactly the training labels; nothing else can be emitted | `@Generable` enum / `anyOf` guide with constrained decoding; open-vocabulary via `contentTagging` |
| Confidence / threshold | Per-label probabilities from `predictedLabelHypotheses`; Apple advises per-class calibrated thresholds | None exposed; greedy sampling for determinism only |
| Multi-label | Top-k with thresholds, or one binary classifier per theme (both undocumented patterns) | Array property with `maximumCount`; native |
| Inference cost | "real time" sentiment; embedding lookups "a couple of milliseconds"; classifier latency and size not published | 3B-parameter 2-bit model shipped with OS; model load latency, `prewarm`; no numbers published |
| App bundle impact | One `.mlmodel` per classifier (size unpublished); no LLM | None |
| Behaviour drift | Model fixed at build time | Model changes with OS updates (26.0–26.3, 26.4, 27.0); Apple says re-test prompts per version |
| Sensitive-content behaviour | None; classifier always answers | Guardrails may throw on self-harm or similar content; cannot be relaxed for guided generation |

## 5. Recommendation

**This section is a recommendation, not a documented fact.**

### Job (a): mood suggestion (five fixed moods)

Use NaturalLanguage with a developer-trained Create ML `MLTextClassifier` loaded through `NLModel`. Reasons:

1. It is the only option that covers all seven locales including Bulgarian and every iPhone on iOS 26. Foundation Models excludes Bulgarian outright and every iPhone older than the 15 Pro, so a Foundation Models mood suggestion would be a feature for a subset of users, with a second implementation needed for the rest.
2. The five moods are a closed set that the classifier cannot step outside of, and `predictedLabelHypotheses` gives a per-label probability, so the app can suggest only when the top label clears a per-class threshold calibrated on held-out data (Apple's own guidance) and stay silent otherwise. Foundation Models gives no probability at all, which makes "suggest only when sure" impossible to implement honestly.
3. The classifier is fixed at build time and answers every entry. The Foundation Models model changes with OS updates and can throw `guardrailViolation` or `refusal` on precisely the low-mood entries the feature most needs to handle; that failure mode is not configurable under guided generation.
4. Cost is the developer's: a labelled dataset of short journal-style sentences per mood, per language (order of hundreds per class per language based on Apple's demos; the exact number is unverified). Start with `maxEnt` for a quick baseline, then `transferLearning(.bertEmbedding)`. Open question to settle in a spike: whether one model can span the Latin and Cyrillic script groups or whether Think ships one Latin model plus one Cyrillic (bg) model and picks by `NLLanguageRecognizer`.

Do not use `NLTagger` sentiment as the primary signal: it is a single valence axis with no Bulgarian support that returns an unflagged, meaningless score for unsupported languages, and it cannot separate `good` from `sharp` or `low` from `flat`. It could serve as an extra input feature or as a sanity check on the classifier's positive/negative direction.

### Job (b): theme tagging (fixed set of five or six themes, several per entry)

Use NaturalLanguage here too, for the same coverage and threshold reasons, with one of two shapes decided by a small spike: a single `MLTextClassifier` over all theme labels using top-k hypotheses above per-class thresholds, or one binary classifier per theme (cleaner multi-label semantics, N model files). Both need the same kind of labelled data as job (a), so one labelling pass can serve both jobs.

Foundation Models is a reasonable **progressive enhancement** for job (b) only: on eligible devices in the six supported locales, a `@Generable` struct with `@Guide(.maximumCount(3))` over a `String` array constrained by `anyOf` (or a `[Theme]` enum array) is native multi-label with constrained decoding and no training data. If the team wants it, gate it on `SystemLanguageModel.default.availability == .available` and `supportsLocale()`, fall back to the NaturalLanguage path otherwise, treat guardrail and refusal errors as "no tags", and re-test on each OS model version. The `contentTagging` use case is not a fit for a fixed label set; its output is open vocabulary and would need a mapping step.

### What to verify before committing

- Bulgarian on iOS: confirm on an iPhone (not this Mac) that `NLContextualEmbedding(language: .bulgarian)?.requestAssets` succeeds and that a Create ML BERT classifier trained with the Cyrillic script classifies Bulgarian text; the probe above shows the model exists but its assets were not present locally.
- Classifier bundle size and per-call latency on a low-end iOS 26 iPhone (Apple publishes neither).
- Whether one model or two script-specific models are needed.
- If the Foundation Models enhancement is pursued: measured guardrail/refusal rate on realistic low-mood entries.

## 6. Source list

- Natural Language framework: https://developer.apple.com/documentation/naturallanguage
- sentimentScore: https://developer.apple.com/documentation/naturallanguage/nltagscheme/sentimentscore
- availableTagSchemes(for:language:): https://developer.apple.com/documentation/naturallanguage/nltagger/availabletagschemes(for:language:)
- NLEmbedding: https://developer.apple.com/documentation/naturallanguage/nlembedding
- sentenceEmbedding(for:): https://developer.apple.com/documentation/naturallanguage/nlembedding/sentenceembedding(for:)
- supportedRevisions(for:): https://developer.apple.com/documentation/naturallanguage/nlembedding/supportedrevisions(for:)
- Finding similarities between pieces of text: https://developer.apple.com/documentation/naturallanguage/finding-similarities-between-pieces-of-text
- NLContextualEmbedding: https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding
- NLModel: https://developer.apple.com/documentation/naturallanguage/nlmodel
- predictedLabelHypotheses(for:maximumCount:): https://developer.apple.com/documentation/naturallanguage/nlmodel/predictedlabelhypotheses(for:maximumcount:)
- MLTextClassifier: https://developer.apple.com/documentation/createml/mltextclassifier
- MLTextClassifier.ModelAlgorithmType: https://developer.apple.com/documentation/createml/mltextclassifier/modelalgorithmtype
- MLTextClassifier.FeatureExtractorType: https://developer.apple.com/documentation/createml/mltextclassifier/featureextractortype
- Creating a text classifier model: https://developer.apple.com/documentation/createml/creating-a-text-classifier-model
- WWDC19 232, Advances in Natural Language Framework: https://developer.apple.com/videos/play/wwdc2019/232/
- WWDC20 10657, Make apps smarter with Natural Language: https://developer.apple.com/videos/play/wwdc2020/10657/
- WWDC23 10042, Explore Natural Language multilingual models: https://developer.apple.com/videos/play/wwdc2023/10042/
- Foundation Models: https://developer.apple.com/documentation/foundationmodels
- Foundation Models updates: https://developer.apple.com/documentation/updates/foundationmodels
- SystemLanguageModel: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- SystemLanguageModel.Availability.UnavailableReason: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason
- supportedLanguages: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportedlanguages
- contextSize: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize
- Supporting languages and locales with Foundation Models: https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- Managing the context window: https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- Generable: https://developer.apple.com/documentation/foundationmodels/generable
- Generating Swift data structures with guided generation: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
- GenerationGuide: https://developer.apple.com/documentation/foundationmodels/generationguide
- GenerationGuide.anyOf(_:): https://developer.apple.com/documentation/foundationmodels/generationguide/anyof(_:)
- GenerationOptions: https://developer.apple.com/documentation/foundationmodels/generationoptions
- GenerationOptions.SamplingMode: https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct
- SamplingMode.greedy: https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct/greedy
- LanguageModelSession.Response: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/response
- LanguageModelSession.GenerationError: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror
- Categorizing and organizing data with content tags: https://developer.apple.com/documentation/foundationmodels/categorizing-and-organizing-data-with-content-tags
- SystemLanguageModel.UseCase.contentTagging: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase/contenttagging
- Improving the safety of generative model output: https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output
- Guardrails.permissiveContentTransformations: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations
- Analyzing the runtime performance of your Foundation Models app: https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app
- WWDC25 286, Meet the Foundation Models framework: https://developer.apple.com/videos/play/wwdc2025/286/
- WWDC25 259, Code-along: Bring on-device AI to your app using the Foundation Models framework: https://developer.apple.com/videos/play/wwdc2025/259/
- Apple Intelligence Foundation Language Models Tech Report 2025: https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025
- Apple Support, How to get Apple Intelligence (devices, storage, languages): https://support.apple.com/121115
- Apple Newsroom, New Apple Intelligence features are available today (2025-09-15): https://www.apple.com/newsroom/2025/09/new-apple-intelligence-features-are-available-today/
- Apple Developer releases feed (iOS 27.0 on 2026-09-14): https://developer.apple.com/news/releases/
