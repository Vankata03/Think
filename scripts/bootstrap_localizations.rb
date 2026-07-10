#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "open3"
require "cgi"

root = File.expand_path("..", __dir__)
catalog_paths = %w[
  Think/Localizable.xcstrings
  Think/InfoPlist.xcstrings
  ThinkWatch/Localizable.xcstrings
  ThinkWidgets/Localizable.xcstrings
  ThinkWatchWidgets/Localizable.xcstrings
  ThinkShared/Content.xcstrings
].map { |path| File.join(root, path) }

languages = {
  "bg" => "Bulgarian",
  "de" => "German",
  "es" => "neutral international Spanish",
  "fr" => "French",
  "it" => "Italian",
  "pt-BR" => "Brazilian Portuguese"
}

provider = ENV.fetch("LOCALIZATION_PROVIDER", "none")
abort "Unknown provider: #{provider}" unless %w[none deepl claude ollama].include?(provider)
model = ENV.fetch("LOCALIZATION_MODEL", provider == "claude" ? "sonnet" : "qwen2.5-coder:latest")
default_batch_size = provider == "deepl" ? "50" : (provider == "claude" ? "40" : "35")
batch_size = Integer(ENV.fetch("LOCALIZATION_BATCH_SIZE", default_batch_size))
concurrency = Integer(ENV.fetch("LOCALIZATION_CONCURRENCY", "1"))
force = ENV["FORCE_LOCALIZATION"] == "1"
overrides_only = ENV["APPLY_OVERRIDES_ONLY"] == "1"
requested = ARGV.empty? ? languages.keys : ARGV
abort "Unknown locale: #{(requested - languages.keys).join(', ')}" unless (requested - languages.keys).empty?

catalogs = catalog_paths.to_h { |path| [path, JSON.parse(File.read(path, encoding: "UTF-8"))] }
overrides_path = File.join(root, "scripts/localization_overrides.json")
overrides = File.exist?(overrides_path) ? JSON.parse(File.read(overrides_path, encoding: "UTF-8")) : {}

def source_value(key, item)
  item.dig("localizations", "en", "stringUnit", "value") || key
end

def placeholders(text)
  text.scan(/%(?:\d+\$)?(?:lld|ld|d|f|@)/).sort
end

def invariant?(text)
  return true if ["Think", "THINK", "“", "“%@”"].include?(text)
  text.gsub(/%(?:\d+\$)?(?:lld|ld|d|f|@)/, "").match?(/\A[\d\s\/:.-]*\z/)
end

def mask_placeholders(text)
  values = []
  masked = CGI.escapeHTML(text).gsub(/%(?:\d+\$)?(?:lld|ld|d|f|@)/) do |placeholder|
    index = values.length
    values << placeholder
    %(<x id="#{index}"/>)
  end
  [masked, values]
end

def restore_placeholders(text, values)
  restored = text.gsub(%r{<x\s+id=["'](\d+)["']\s*/>|<x\s+id=["'](\d+)["']\s*>\s*</x>}) do
    index = (Regexp.last_match(1) || Regexp.last_match(2)).to_i
    values.fetch(index)
  end
  raise "Provider changed a placeholder token: #{text.inspect}" if restored.include?("<x")
  CGI.unescapeHTML(restored)
end

def localized?(item, locale)
  localization = item.dig("localizations", locale)
  return false unless localization

  values = []
  visit = lambda do |node|
    return unless node.is_a?(Hash)
    if node["stringUnit"].is_a?(Hash)
      values << node.dig("stringUnit", "value")
    else
      node.each_value { |child| visit.call(child) }
    end
  end
  visit.call(localization)
  !values.empty?
end

def has_variations?(item, locale)
  item.dig("localizations", locale, "variations").is_a?(Hash)
end

def deepl_translate(language, entries)
  key = ENV.fetch("DEEPL_AUTH_KEY")
  endpoint = ENV.fetch(
    "DEEPL_API_URL",
    key.end_with?(":fx") ? "https://api-free.deepl.com/v2/translate" : "https://api.deepl.com/v2/translate"
  )
  target = {
    "Bulgarian" => "BG",
    "German" => "DE",
    "neutral international Spanish" => "ES",
    "French" => "FR",
    "Italian" => "IT",
    "Brazilian Portuguese" => "PT-BR"
  }.fetch(language)

  masked = entries.map { |_, source| mask_placeholders(source) }
  uri = URI(endpoint)
  request = Net::HTTP::Post.new(uri, "Authorization" => "DeepL-Auth-Key #{key}", "Content-Type" => "application/json")
  body = {
    text: masked.map(&:first),
    source_lang: "EN",
    target_lang: target,
    tag_handling: "xml",
    context: "Think is a calm reflective app. Its voice is concise, direct, natural, and personal."
  }
  body[:formality] = "prefer_less" unless target == "BG"
  body[:glossary_id] = ENV["DEEPL_GLOSSARY_ID"] if ENV["DEEPL_GLOSSARY_ID"]
  request.body = JSON.generate(body)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 120
  response = http.request(request)
  raise "DeepL failed: HTTP #{response.code}: #{response.body[0, 300]}" unless response.is_a?(Net::HTTPSuccess)

  translations = JSON.parse(response.body).fetch("translations")
  raise "DeepL returned #{translations.length} translations for #{entries.length} strings" unless translations.length == entries.length

  entries.each_with_index.to_h do |(id, source), index|
    translated = restore_placeholders(translations.fetch(index).fetch("text"), masked.fetch(index).last)
    raise "Placeholder mismatch for #{id}: #{source.inspect} -> #{translated.inspect}" unless placeholders(source) == placeholders(translated)
    [id, translated]
  end
end

def translate_batch(provider, model, language, entries)
  return deepl_translate(language, entries) if provider == "deepl"

  payload = entries.to_h { |id, value| [id.to_s, value] }
  prompt = <<~PROMPT
    You are the senior native-language editor for Think, a calm reflective iOS app.
    Translate the JSON values from English into #{language}. Return one JSON object
    with exactly the same numeric keys and translated string values. No notes.

    Voice: concise, natural, direct, meaningful, never corporate or motivational spam.
    Transcreate metaphors so they sound written in #{language}; do not preserve awkward
    English idioms literally. Use informal singular "you" appropriate for a personal app.
    Preserve the product name Think. Preserve every printf placeholder such as %@ and
    %lld exactly, but reorder placeholders when grammar requires it. Preserve punctuation
    needed by the language. Daily lines should stay compact; prefer under 110 characters.
    Questions and actions should prefer under 125 characters. Translate ancient author
    names using the conventional form in #{language}.

    Return only the JSON object. Do not wrap it in Markdown and do not explain choices.

    #{JSON.generate(payload)}
  PROMPT

  raw = if provider == "claude"
          stdout, stderr, status = Open3.capture3(
            "claude", "-p", "--model", model, "--max-turns", "1", "--output-format", "text",
            "--no-session-persistence", prompt
          )
          raise "Claude failed: #{stderr}" unless status.success?
          stdout
        elsif provider == "ollama"
          uri = URI("http://127.0.0.1:11434/api/generate")
          request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
          request.body = JSON.generate(
            model: model,
            prompt: prompt,
            stream: false,
            format: "json",
            options: { temperature: 0.15, num_ctx: 16_384 }
          )
          response = Net::HTTP.start(uri.host, uri.port, read_timeout: 600) { |http| http.request(request) }
          raise "Ollama failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
          JSON.parse(response.body).fetch("response")
        else
          raise "Set LOCALIZATION_PROVIDER=deepl, claude, or ollama"
        end
  json = raw[/\{.*\}/m]
  raise "Provider did not return JSON: #{raw[0, 500]}" unless json
  parsed = JSON.parse(json)
  entries.to_h do |id, source|
    translated = parsed.fetch(id.to_s)
    raise "Placeholder mismatch for #{id}: #{source.inspect} -> #{translated.inspect}" unless placeholders(source) == placeholders(translated)
    [id, translated]
  end
end

requested.each do |locale|
  if force
    catalogs.each_value do |catalog|
      catalog.fetch("strings", {}).each_value do |item|
        next if has_variations?(item, locale)
        item.fetch("localizations", {}).delete(locale)
      end
    end
    catalogs.each { |path, catalog| File.write(path, JSON.pretty_generate(catalog) + "\n", encoding: "UTF-8") }
  end

  unique_values = {}
  catalogs.each_value do |catalog|
    catalog.fetch("strings", {}).each do |key, item|
      next if item["shouldTranslate"] == false
      value = source_value(key, item)
      unique_values[value] ||= []
      unique_values[value] << [key, item]
    end
  end

  protected_values = {}

  unique_values.each do |value, occurrences|
    next unless invariant?(value)
    protected_values[value] = true
    occurrences.each do |_, item|
      item["localizations"] ||= {}
      item["localizations"][locale] = {
        "stringUnit" => { "state" => "translated", "value" => value }
      }
    end
  end

  overrides.fetch(locale, {}).each do |source, translated|
    next unless unique_values.key?(source)
    protected_values[source] = true
    raise "Placeholder mismatch in override: #{source.inspect}" unless placeholders(source) == placeholders(translated)
    unique_values.fetch(source).each do |_, item|
      item["localizations"] ||= {}
      item["localizations"][locale] = {
        "stringUnit" => { "state" => "translated", "value" => translated }
      }
    end
  end

  # Persist invariants and editorial overrides even when an external provider
  # is unavailable. Provider batches continue to save incrementally below.
  catalogs.each do |path, catalog|
    File.write(path, JSON.pretty_generate(catalog) + "\n", encoding: "UTF-8")
  end

  missing = unique_values.keys.reject do |value|
    next true if protected_values[value]
    next true if unique_values[value].all? { |_, item| has_variations?(item, locale) }
    next false if force
    unique_values[value].all? { |_, item| localized?(item, locale) }
  end

  if overrides_only
    puts "#{locale}: applied overrides; #{missing.length} unique strings remain"
    next
  end

  if provider == "none" && !missing.empty?
    abort "#{locale}: #{missing.length} strings need translation; choose LOCALIZATION_PROVIDER explicitly"
  end

  slices = missing.each_slice(batch_size).to_a
  jobs = Queue.new
  completed = Queue.new
  slices.each_with_index { |slice, index| jobs << [index, slice] }

  workers = [concurrency, slices.length].min.times.map do
    Thread.new do
      loop do
        index, slice = jobs.pop(true)
        batch = slice.each_with_index.map { |value, offset| [offset, value] }
        attempts = 0
        begin
          attempts += 1
          result = translate_batch(provider, model, languages.fetch(locale), batch)
          completed << [:ok, index, slice, result]
        rescue StandardError => error
          if attempts < 5
            delay = attempts * 20
            warn "#{locale}: retrying batch #{index + 1} after #{error.class} in #{delay}s"
            sleep(delay)
            retry
          end
          raise
        end
      rescue ThreadError
        break
      rescue StandardError => error
        completed << [:error, index, slice, error]
        break
      end
    end
  end

  processed = 0
  slices.length.times do
    status, _, slice, result = completed.pop
    raise result if status == :error
    translations = result
    slice.each_with_index do |source, offset|
      value = translations.fetch(offset)
      unique_values.fetch(source).each do |_, item|
        item["localizations"] ||= {}
        item["localizations"][locale] = {
          "stringUnit" => { "state" => "translated", "value" => value }
        }
      end
    end
    catalogs.each do |path, catalog|
      File.write(path, JSON.pretty_generate(catalog) + "\n", encoding: "UTF-8")
    end
    processed += slice.length
    puts "#{locale}: translated #{processed}/#{missing.length} unique strings"
    $stdout.flush
  end
  workers.each(&:join)
  puts "#{locale}: catalog drafts written"
end
