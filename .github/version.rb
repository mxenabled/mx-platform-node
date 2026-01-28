require "yaml"

# Default to config-v20111101 file if not provided for backwards compatibility
# This is because automated openapi repository dispatch currently only generates v20111101
config_file = ARGV[1] || "openapi/config-v20111101.yml"

config = ::YAML.load(::File.read(config_file))
major, minor, patch = config["npmVersion"].split(".")

# Note: "skip" logic is handled by workflow (version.rb not called when skip selected)
# Only minor and patch bumps are supported (major version locked to API version)
case ARGV[0]
when "minor"
  minor = minor.succ
  patch = 0
when "patch"
  patch = patch.succ
else
  raise "Invalid version bump type: #{ARGV[0]}. Supported: 'minor' or 'patch'"
end

config["npmVersion"] = "#{major}.#{minor}.#{patch}"
::File.open(config_file, 'w') { |file| ::YAML.dump(config, file) }
puts config["npmVersion"]
