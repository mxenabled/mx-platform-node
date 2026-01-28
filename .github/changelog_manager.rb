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
    # CLI entry point: validates arguments and updates changelog
    # Called from GitHub Actions workflows
    #
    # @param versions_arg [String, nil] Versions from ARGV[0]
    # @return [true] Returns true on success
    # @raise SystemExit If validation fails
    def run(versions_arg)
      # Validate versions argument
      validate_versions(versions_arg)
      update(versions_arg)
      puts "✅ CHANGELOG updated successfully"
    end

    # Public interface: update CHANGELOG with new version entries
    #
    # @param versions [String, Array] Version(s) to update. String format: "v20250224,v20111101"
    # @return [true] Returns true on success
    # @raise [StandardError] If versions not found or changelog not readable
    def update(versions)
      versions_array = normalize_versions(versions)

      # Check changelog exists first before doing any processing
      unless File.exist?(CHANGELOG_PATH)
        raise "Changelog not found at #{CHANGELOG_PATH}"
      end

      # Read version numbers from each version's package.json
      version_data = versions_array.map do |api_version|
        version_number = read_package_version(api_version)
        raise "Could not read version from #{api_version}/package.json" if version_number.nil? || version_number.empty?
        [api_version, version_number]
      end

      # Sort by API_VERSION_ORDER to ensure consistent ordering
      sorted_data = sort_versions(version_data)

      # Read existing changelog
      current_changelog = File.read(CHANGELOG_PATH)

      # Build changelog entries for each version
      entries = sorted_data.map { |api_version, version_num| build_entry(api_version, version_num, TODAY) }

      # Insert entries at the top of changelog (after header)
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

    # Normalize versions parameter to array
    # @param versions [String, Array]
    # @return [Array<String>] Array of version strings
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

    # Read version number from a specific API version's package.json
    # @param api_version [String] e.g., "v20250224"
    # @return [String] Version number from package.json
    def read_package_version(api_version)
      package_json_path = File.join(BASE_PATH, api_version, 'package.json')

      unless File.exist?(package_json_path)
        raise "Package file not found at #{package_json_path}"
      end

      package_json = JSON.parse(File.read(package_json_path))
      package_json['version']
    end

    # Sort versions by API_VERSION_ORDER
    # @param version_data [Array<Array>] Array of [api_version, version_number] pairs
    # @return [Array<Array>] Sorted array of [api_version, version_number] pairs
    def sort_versions(version_data)
      version_data.sort_by do |api_version, _|
        order_index = API_VERSION_ORDER.index(api_version)
        order_index || Float::INFINITY
      end
    end

    # Build a single changelog entry
    # @param api_version [String] e.g., "v20250224"
    # @param version_number [String] e.g., "3.2.0"
    # @param date [Date] Entry date
    # @return [String] Formatted changelog entry
    def build_entry(api_version, version_number, date)
      date_str = date.strftime('%Y-%m-%d')
      last_change_date = extract_last_change_date(api_version)

      # Format the message with last change date if found
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
    # @param api_version [String] e.g., "v20250224"
    # @return [Date, nil] Date of last change or nil if not found
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
    #
    # @param changelog [String] Current changelog content
    # @param entries [Array<String>] Entries to insert
    # @return [String] Updated changelog
    def insert_entries(changelog, entries)
      lines = changelog.split("\n")

      # Find the line number of the first version entry (first line starting with ##)
      first_entry_index = lines.find_index { |line| line.start_with?('## [') }

      if first_entry_index.nil?
        raise "Could not find existing changelog entries. Expected format: ## [version]"
      end

      # Extract header (everything before first entry)
      header = lines[0...first_entry_index]

      # Get the rest (from first entry onwards)
      rest = lines[first_entry_index..]

      # Combine: header + new entries + rest
      (header + entries.map { |e| e.rstrip } + [''] + rest).join("\n")
    end
  end
end

# CLI Interface - allows usage from GitHub Actions
ChangelogManager.run(ARGV[0]) if __FILE__ == $0
