require "yaml"

# Support both single config and multi-version config approaches
# For multi-version POC, we can specify which config file to use
config_file = ARGV[1] || "openapi/config.yml"

config = ::YAML.load(::File.read(config_file))
major, minor, patch = config["npmVersion"].split(".")

case ARGV[0]
when "major"
  major = major.succ
  minor = 0
  patch = 0
when "minor"
  minor = minor.succ
  patch = 0
when "patch"
  patch = patch.succ
end

config["npmVersion"] = "#{major}.#{minor}.#{patch}"
::File.open(config_file, 'w') { |file| ::YAML.dump(config, file) }
puts config["npmVersion"]
