require "fileutils"

ALLOW_LIST = [
  ".git",
  ".github",
  ".openapi-generator-ignore",
  "LICENSE",
  "openapi"
].freeze

::Dir.each_child(::Dir.pwd) do |source|
  next if ALLOW_LIST.include?(source)

  ::FileUtils.rm_rf("#{::Dir.pwd}/#{source}")
end
