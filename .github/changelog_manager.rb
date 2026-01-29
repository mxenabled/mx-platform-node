require 'json'
require 'date'

class ChangelogManager
  CHANGELOG_PATH = 'CHANGELOG.md'.freeze
  BASE_PATH = '.'.freeze
  TODAY = Date.today.freeze

  # API versions in priority order (newest first)
  # This ensures most recent API version entries appear before older API versions in the log
  API_VERSION_ORDER = ['v20250224', 'v20111101'].freeze

  class << self
    def run(versions_arg)
      validate_versions(versions_arg)
      update(versions_arg)
      puts "✅ CHANGELOG updated successfully"
    end

    def update(versions)
      versions_array = normalize_versions(versions)

      unless File.exist?(CHANGELOG_PATH)
        raise "Changelog not found at #{CHANGELOG_PATH}"
      end

      # Read version numbers from each version's package.json
      version_data = versions_array.map do |api_version|
        version_number = read_package_version(api_version)
        raise "Could not read version from #{api_version}/package.json" if version_number.nil? || version_number.empty?
        [api_version, version_number]
      end

      sorted_data = sort_versions(version_data)
      current_changelog = File.read(CHANGELOG_PATH)

      # Build changelog entries for each version and updated changelog
      entries = sorted_data.map { |api_version, version_num| build_entry(api_version, version_num, TODAY) }
      updated_changelog = insert_entries(current_changelog, entries)

      # Write back to file
      File.write(CHANGELOG_PATH, updated_changelog)

      true
    end

    private

    def validate_versions(versions_arg)
      if versions_arg.nil? || versions_arg.empty?
        puts "Usage: ruby changelog_manager.rb <versions>"
        puts "Example: ruby changelog_manager.rb 'v20250224,v20111101'"
        puts "Supported versions: #{API_VERSION_ORDER.join(', ')}"
        exit 1
      end

      if has_invalid_versions?(versions_arg)
        puts "❌ Error: Invalid versions. Supported versions: #{API_VERSION_ORDER.join(', ')}"
        exit 1
      end
    end

    def has_invalid_versions?(versions_arg)
      versions_array = versions_arg.split(',').map(&:strip)
      invalid_versions = versions_array - API_VERSION_ORDER
      invalid_versions.any?
    end

    def normalize_versions(versions)
      case versions
      when String
        versions.split(',').map(&:strip)
      when Array
        versions.map(&:to_s)
      else
        raise "Versions must be String or Array, got #{versions.class}"
      end
    end

    def read_package_version(api_version)
      package_json_path = File.join(BASE_PATH, api_version, 'package.json')

      unless File.exist?(package_json_path)
        raise "Package file not found at #{package_json_path}"
      end

      package_json = JSON.parse(File.read(package_json_path))
      package_json['version']
    end


    def sort_versions(version_data)
      version_data.sort_by do |api_version, _|
        order_index = API_VERSION_ORDER.index(api_version)
        order_index || Float::INFINITY
      end
    end

    def build_entry(api_version, version_number, date)
      date_str = date.strftime('%Y-%m-%d')
      last_change_date = extract_last_change_date(api_version)

      if last_change_date
        last_change_str = last_change_date.strftime('%Y-%m-%d')
        message = "Updated #{api_version} API specification to most current version. Please check full [API changelog](https://docs.mx.com/resources/changelog/platform) for any changes made between #{last_change_str} and #{date_str}."
      else
        message = "Updated #{api_version} API specification to most current version. Please check full [API changelog](https://docs.mx.com/resources/changelog/platform) for any changes."
      end

      <<~ENTRY
        ## [#{version_number}] - #{date_str} (#{api_version} API)
        #{message}
      ENTRY
    end

    # Extract the date of the last change for a given API version from the changelog
    # Finds the first entry in the changelog that mentions the api_version
    # such as "v20250224" and returns date of last change or nil if not found
    def extract_last_change_date(api_version)
      return nil unless File.exist?(CHANGELOG_PATH)

      File.readlines(CHANGELOG_PATH).each do |line|
        # Look for lines like: ## [2.0.0] - 2025-01-15 (v20111101 API)
        if line.match?(/## \[\d+\.\d+\.\d+\]\s*-\s*(\d{4}-\d{2}-\d{2})\s*\(#{Regexp.escape(api_version)}\s+API\)/)
          # Extract the date from the line
          match = line.match(/(\d{4}-\d{2}-\d{2})/)
          return Date.parse(match[1]) if match
        end
      end

      nil
    end

    # Insert entries into changelog after the header section
    # Finds the first ## entry and inserts new entries before it
    def insert_entries(changelog, entries)
      lines = changelog.split("\n")

      first_entry_index = lines.find_index { |line| line.start_with?('## [') }

      if first_entry_index.nil?
        raise "Could not find existing changelog entries. Expected format: ## [version]"
      end

      header = lines[0...first_entry_index]
      rest = lines[first_entry_index..]

      # Combine: header + new entries + rest
      (header + entries.map { |e| e.rstrip } + [''] + rest).join("\n")
    end
  end
end

# CLI Interface - allows usage from GitHub Actions
ChangelogManager.run(ARGV[0]) if __FILE__ == $0
