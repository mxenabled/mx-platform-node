require "yaml"

# ConfigValidator validates SDK configuration files before generation
# Ensures semantic versioning rules are enforced and configs are properly structured
class ConfigValidator
  SUPPORTED_VERSIONS = {
    "v20111101" => 2,
    "v20250224" => 3
  }.freeze

  def self.validate!(config_file, api_version)
    new(config_file, api_version).validate!
  end

  def initialize(config_file, api_version)
    @config_file = config_file
    @api_version = api_version
  end

  def validate!
    check_api_version_supported!
    check_config_exists!
    check_config_readable!
    validate_semantic_versioning!
    true
  end

  private

  def check_api_version_supported!
    unless SUPPORTED_VERSIONS.key?(@api_version)
      supported = SUPPORTED_VERSIONS.keys.join(", ")
      raise "Invalid API version: #{@api_version}. Supported versions: #{supported}"
    end
  end

  def check_config_exists!
    unless File.exist?(@config_file)
      raise "Config file not found: #{@config_file}"
    end
  end

  def check_config_readable!
    begin
      config = YAML.load(File.read(@config_file))
      # YAML.load can return a string if file contains only invalid YAML
      # We need to ensure it returned a Hash (parsed YAML object)
      unless config.is_a?(Hash)
        raise "Config file does not contain valid YAML structure: #{@config_file}"
      end
    rescue Psych::SyntaxError => e
      raise "Config file syntax error in #{@config_file}: #{e.message}"
    rescue StandardError => e
      raise "Could not read config file #{@config_file}: #{e.message}"
    end
  end

  def validate_semantic_versioning!
    config = YAML.load(File.read(@config_file))

    unless config.key?("npmVersion")
      raise "Config missing npmVersion field: #{@config_file}"
    end

    npm_version = config["npmVersion"].to_s.strip
    major_version = npm_version.split(".")[0].to_i

    expected_major = SUPPORTED_VERSIONS[@api_version]

    if major_version != expected_major
      raise "Semantic versioning error: #{@api_version} API must use npm major version #{expected_major}, " \
            "found #{major_version} in #{@config_file}\n" \
            "Current npmVersion: #{npm_version}\n" \
            "Update config with correct major version: #{expected_major}.x.x"
    end
  end
end

# CLI Interface - allows direct execution from GitHub Actions
ConfigValidator.validate!(ARGV[0], ARGV[1]) if __FILE__ == $0
