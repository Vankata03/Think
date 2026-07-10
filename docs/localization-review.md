# Localization review

The source of truth is the native Xcode String Catalogs in the repository.
English is the fallback language. Initial machine-assisted translations are
drafts until a native reviewer signs off on every surface for that locale.
Bulgarian has received a complete connected editorial pass across all 100
practices; the table still requires independent native sign-off and layout QA.

## Initial locales

| Locale | Language | Draft coverage | Content review | UI review | Layout review | Release-ready |
|---|---|---:|---:|---:|---:|---:|
| `bg` | Bulgarian | Complete | Pending | Pending | Pending | No |
| `de` | German | Complete | Pending | Pending | Pending | No |
| `es` | Spanish | Complete | Pending | Pending | Pending | No |
| `fr` | French | Complete | Pending | Pending | Pending | No |
| `it` | Italian | Complete | Pending | Pending | Pending | No |
| `pt-BR` | Brazilian Portuguese | Complete | Pending | Pending | Pending | No |

## Required review

- Read all 100 line → question → action practices as connected units.
- Rewrite literal translations, English idioms, and motivational clichés.
- Confirm attributed lines preserve the idea of the cleared source excerpt.
  Localized wording is a fresh Think translation based on the public-domain
  George Long edition, not a copied modern translation.
- Confirm daily lines remain compact on iPhone, widgets, and Apple Watch.
- Check placeholders, plurals, accessibility labels, notifications, feedback
  email subjects, Photo Library purpose text, and App Store metadata.
- Run UI tests with the locale and inspect localization screenshots in light and
  dark mode.

Do not advertise a locale or add localized App Store metadata until all four
review columns are complete.

Run `ruby scripts/validate_localizations.rb bg` before shipping Bulgarian.
The validator requires every catalog entry and checks printf placeholders.

## Efficient workflow

Do not use a general-purpose chat model to translate the full catalog. The
catalog itself is the translation memory: existing values are reused and only
new English source values are sent to a provider.
The bootstrap script defaults to no provider, so an accidental run cannot use
Claude, ChatGPT, DeepL, or local-model quota.

1. Run `scripts/sync_string_catalogs.sh` after UI/content changes. This builds
   every target and extracts iPhone, Watch, widget, complication, accessibility,
   notification, and Info.plist text.
2. Apply committed editorial corrections without any provider call:
   `APPLY_OVERRIDES_ONLY=1 ruby scripts/bootstrap_localizations.rb bg`.
3. For a new locale, use DeepL in batches of at most 50 strings:
   `LOCALIZATION_PROVIDER=deepl DEEPL_AUTH_KEY=... ruby scripts/bootstrap_localizations.rb de`.
   The key stays in the environment and is never stored in the repository.
4. Review the 100 connected practices and any layout warnings. Use a chat model
   only for individually flagged phrases, never for the whole catalog.
5. Run `ruby scripts/validate_localizations.rb LOCALE` and locale UI tests.

Current source is 24,097 unique characters per locale (564 unique source
values). All six initial locales are about 144,582 source characters total,
before future additions.
