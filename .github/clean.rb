require "fileutils"

ALLOW_LIST = [
  ".git",
  ".github",
  ".gitignore",
  ".npmignore",
  ".openapi-generator-ignore",
  "CHANGELOG.md",
  "LICENSE",
  "MIGRATION.md",
  "latest",
  "node_modules",
  "openapi",
  "openapitools.json",
  "tmp"
].freeze

::Dir.each_child(::Dir.pwd) do |source|
  next if ALLOW_LIST.include?(source)

  # Preserve test-output directories for multi-version POC testing
  next if source.start_with?("test-output-")

  ::FileUtils.rm_rf("#{::Dir.pwd}/#{source}")
end
