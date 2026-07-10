#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

root = File.expand_path("..", __dir__)
source_path = File.join(root, "ThinkShared/Models/ContentLibrary.swift")
paths_path = File.join(root, "ThinkShared/Models/ThinkingPath.swift")
catalog_path = File.join(root, "ThinkShared/Content.xcstrings")
source = File.read(source_path, encoding: "UTF-8")

block = source[/private static let sourcePractices: \[DailyPractice\] = \[(.*?)\n    \]\n\n    \/\/\/ Content uses/m, 1]
abort "Could not find sourcePractices" unless block

entries = []
block.scan(/practice\(\s*\n\s*(original|marcus|epictetus)\("((?:[^"\\]|\\.)*)".*?\),\s*\n\s*"((?:[^"\\]|\\.)*)",\s*\n\s*"((?:[^"\\]|\\.)*)"\s*\n\s*\)/m) do |kind, line, question, action|
  decode = ->(value) { JSON.parse(%("#{value}")) }
  author = { "original" => "Think", "marcus" => "Marcus Aurelius", "epictetus" => "Epictetus" }.fetch(kind)
  entries << [decode.call(line), author, decode.call(question), decode.call(action)]
end

abort "Expected 100 practices, found #{entries.count}" unless entries.count == 100

catalog = if File.exist?(catalog_path)
            JSON.parse(File.read(catalog_path, encoding: "UTF-8"))
          else
            { "sourceLanguage" => "en", "strings" => {}, "version" => "1.0" }
          end
catalog["strings"] ||= {}

add_entry = lambda do |key, value, comment|
  item = catalog["strings"][key] ||= {}
  item["comment"] = comment
  item["extractionState"] = "manual"
  item["localizations"] ||= {}
  item["localizations"]["en"] = {
    "stringUnit" => { "state" => "translated", "value" => value }
  }
end

valid_keys = []

entries.each_with_index do |(line, author, question, action), index|
  base = format("practice.%03d", index + 1)
  {
    "#{base}.line" => [line, "Daily practice line. Keep concise and provocative."],
    "#{base}.author" => [author, "Displayed attribution. Think is hidden in the UI."],
    "#{base}.question" => [question, "Reflection question paired with the daily line."],
    "#{base}.action" => [action, "Concrete action paired with the daily line."]
  }.each do |key, (value, comment)|
    add_entry.call(key, value, comment)
    valid_keys << key
  end
end

paths_source = File.read(paths_path, encoding: "UTF-8")
expected_path_keys = []
paths_source.split(/(?=^\s*private static let source\w+)/).each do |path_block|
  path_id = path_block[/^\s*id:\s*"([^"]+)"/, 1]
  next unless path_id

  base = "path.#{path_id}"
  expected_path_keys.concat(["#{base}.name", "#{base}.tagline"])
  path_block.scan(/PathStep\s*\(\s*id:\s*(\d+)/) do |step_id|
    step_base = "#{base}.step.#{step_id.first}"
    expected_path_keys.concat([
      "#{step_base}.title",
      "#{step_base}.lesson",
      "#{step_base}.task"
    ])
  end
end

abort "Could not identify thinking path source blocks" if expected_path_keys.empty?

paths_source.scan(/private static let source\w+ = ThinkingPath\(\s*id: "([^"]+)",\s*name: "([^"]+)",\s*tagline: "([^"]+)",\s*icon: "[^"]+",\s*isAvailable: (?:true|false),\s*steps: \[(.*?)\]\s*\)/m) do |id, name, tagline, steps_block|
  base = "path.#{id}"
  {
    "#{base}.name" => [name, "Thinking path name."],
    "#{base}.tagline" => [tagline, "Short description of a thinking path."]
  }.each do |key, (value, comment)|
    add_entry.call(key, value, comment)
    valid_keys << key
  end

  steps_block.scan(/PathStep\(id: (\d+), title: "((?:[^"\\]|\\.)*)",\s*lesson: "((?:[^"\\]|\\.)*)",\s*task: "((?:[^"\\]|\\.)*)"\)/m) do |step_id, title, lesson, task|
    decode = ->(value) { JSON.parse(%("#{value}")) }
    step_base = "#{base}.step.#{step_id}"
    {
      "#{step_base}.title" => [decode.call(title), "Thinking path step title."],
      "#{step_base}.lesson" => [decode.call(lesson), "Brief lesson for this path step."],
      "#{step_base}.task" => [decode.call(task), "Concrete task for this path step."]
    }.each do |key, (value, comment)|
      add_entry.call(key, value, comment)
      valid_keys << key
    end
  end
end

missing_path_keys = expected_path_keys - valid_keys
abort "Failed to extract thinking path keys: #{missing_path_keys.join(', ')}" unless missing_path_keys.empty?

catalog["strings"].select! { |key, _| valid_keys.include?(key) }

File.write(catalog_path, JSON.pretty_generate(catalog) + "\n", encoding: "UTF-8")
puts "Generated #{catalog["strings"].count} strings from #{entries.count} practices and thinking paths"
