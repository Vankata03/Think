#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

root = File.expand_path("..", __dir__)
catalogs = %w[
  Think/Localizable.xcstrings
  Think/InfoPlist.xcstrings
  ThinkWatch/Localizable.xcstrings
  ThinkWidgets/Localizable.xcstrings
  ThinkWatchWidgets/Localizable.xcstrings
  ThinkShared/Content.xcstrings
].map { |path| [path, JSON.parse(File.read(File.join(root, path), encoding: "UTF-8"))] }

locales = ARGV.empty? ? %w[bg] : ARGV
failures = []

def placeholders(text)
  text.scan(/%(?:\d+\$)?(?:lld|ld|d|f|@)/).sort
end

locales.each do |locale|
  total = 0
  translated = 0

  catalogs.each do |path, catalog|
    catalog.fetch("strings", {}).each do |key, item|
      next if item["shouldTranslate"] == false

      total += 1
      source = item.dig("localizations", "en", "stringUnit", "value") || key
      value = item.dig("localizations", locale, "stringUnit", "value")
      unless value
        failures << "#{locale}: missing #{path}: #{key.inspect}"
        next
      end

      translated += 1
      if placeholders(source) != placeholders(value)
        failures << "#{locale}: placeholder mismatch #{path}: #{key.inspect}"
      end
      if source.include?("Think") && !value.include?("Think")
        failures << "#{locale}: Think brand changed #{path}: #{key.inspect}"
      end
      if key.match?(/practice\.\d+\.line$/) && value.length > 110
        failures << "#{locale}: daily line exceeds 110 characters #{key}: #{value.length}"
      end
      if key.match?(/practice\.\d+\.(question|action)$/) && value.length > 125
        failures << "#{locale}: practice text exceeds 125 characters #{key}: #{value.length}"
      end
    end
  end

  puts "#{locale}: #{translated}/#{total} catalog entries"
end

abort failures.join("\n") unless failures.empty?
