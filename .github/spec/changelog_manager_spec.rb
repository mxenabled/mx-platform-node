require 'rspec'
require 'json'
require 'date'
require 'fileutils'

# Load the class to test
require_relative '../changelog_manager'

describe ChangelogManager do
  let(:spec_dir) { File.expand_path('..', __FILE__) }
  let(:fixtures_dir) { File.join(spec_dir, 'fixtures') }
  let(:temp_dir) { File.join(spec_dir, 'tmp') }

  before(:each) do
    # Create temp directory for test files
    FileUtils.mkdir_p(temp_dir)

    # Stub constants to use temp directory for tests
    stub_const('ChangelogManager::CHANGELOG_PATH', File.join(temp_dir, 'CHANGELOG.md'))
    stub_const('ChangelogManager::BASE_PATH', temp_dir)
    stub_const('ChangelogManager::TODAY', Date.new(2025, 01, 28))
  end

  after(:each) do
    # Clean up temp directory
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  describe '.update with single version' do
    it 'updates changelog with single version entry' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      package_dir = File.join(temp_dir, 'v20250224')

      FileUtils.mkdir_p(package_dir)
      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20250224_package.json'),
        File.join(package_dir, 'package.json')
      )

      # Execute
      result = ChangelogManager.update('v20250224')

      # Verify
      expect(result).to be true

      updated_content = File.read(changelog_path)
      expect(updated_content).to include('## [3.0.0] - 2025-01-28 (v20250224 API)')
      expect(updated_content).to include('Updated v20250224 API specification to most current version')
      expect(updated_content).to include('[API changelog]')

      # Ensure it appears before existing entries
      v20250224_pos = updated_content.index('[3.0.0]')
      v20111101_pos = updated_content.index('[2.0.0]')
      expect(v20250224_pos).to be < v20111101_pos
    end
  end

  describe '.update with multiple versions' do
    it 'updates changelog with entries from multiple versions' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      v20250224_dir = File.join(temp_dir, 'v20250224')
      v20111101_dir = File.join(temp_dir, 'v20111101')

      FileUtils.mkdir_p(v20250224_dir)
      FileUtils.mkdir_p(v20111101_dir)

      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20250224_package.json'),
        File.join(v20250224_dir, 'package.json')
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20111101_package.json'),
        File.join(v20111101_dir, 'package.json')
      )

      # Execute
      result = ChangelogManager.update('v20250224,v20111101')

      # Verify
      expect(result).to be true

      updated_content = File.read(changelog_path)

      # Both versions should be present
      expect(updated_content).to include('## [3.0.0] - 2025-01-28 (v20250224 API)')
      expect(updated_content).to include('## [2.0.0] - 2025-01-28 (v20111101 API)')
      expect(updated_content).to include('Updated v20250224 API specification to most current version')
      expect(updated_content).to include('Updated v20111101 API specification to most current version')

      # v20250224 should come BEFORE v20111101 (sorting)
      v20250224_pos = updated_content.index('[3.0.0]')
      v20111101_pos = updated_content.index('[2.0.0]')
      expect(v20250224_pos).to be < v20111101_pos
    end
  end

  describe '.update with array versions' do
    it 'accepts versions as an array' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      package_dir = File.join(temp_dir, 'v20250224')

      FileUtils.mkdir_p(package_dir)
      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20250224_package.json'),
        File.join(package_dir, 'package.json')
      )

      # Execute with array instead of string
      result = ChangelogManager.update(['v20250224'])

      # Verify
      expect(result).to be true
      updated_content = File.read(changelog_path)
      expect(updated_content).to include('## [3.0.0] - 2025-01-28 (v20250224 API)')
    end
  end

  describe '.update sorting behavior' do
    it 'always places v20250224 before v20111101' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      v20250224_dir = File.join(temp_dir, 'v20250224')
      v20111101_dir = File.join(temp_dir, 'v20111101')

      FileUtils.mkdir_p(v20250224_dir)
      FileUtils.mkdir_p(v20111101_dir)

      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20250224_package.json'),
        File.join(v20250224_dir, 'package.json')
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20111101_package.json'),
        File.join(v20111101_dir, 'package.json')
      )

      # Execute with reversed input order to verify sorting
      result = ChangelogManager.update('v20111101,v20250224')

      # Verify
      expect(result).to be true
      updated_content = File.read(changelog_path)

      # Despite input order, v20250224 should come first
      v20250224_pos = updated_content.index('[3.0.0]')
      v20111101_pos = updated_content.index('[2.0.0]')
      expect(v20250224_pos).to be < v20111101_pos
    end
  end

  describe '.update with date range behavior' do
    it 'includes date range when prior entry exists for API version' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      package_dir = File.join(temp_dir, 'v20111101')

      FileUtils.mkdir_p(package_dir)
      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20111101_package.json'),
        File.join(package_dir, 'package.json')
      )

      # Execute - updating v20111101 which has an entry dated 2025-01-15 in the fixture
      result = ChangelogManager.update('v20111101')

      # Verify
      expect(result).to be true
      updated_content = File.read(changelog_path)

      # Should include the date range message
      expect(updated_content).to include('between 2025-01-15 and 2025-01-28')
    end

    it 'shows no prior date when entry has no previous version' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      package_dir = File.join(temp_dir, 'v20250224')

      FileUtils.mkdir_p(package_dir)
      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20250224_package.json'),
        File.join(package_dir, 'package.json')
      )

      # Execute - v20250224 has no prior entry in the fixture
      result = ChangelogManager.update('v20250224')

      # Verify
      expect(result).to be true
      updated_content = File.read(changelog_path)

      # Should include fallback message without date range
      expect(updated_content).to include('Updated v20250224 API specification to most current version. Please check full [API changelog]')
      # Should NOT have a "between" clause
      expect(updated_content).not_to match(/between \d{4}-\d{2}-\d{2} and \d{4}-\d{2}-\d{2}.*v20250224/)
    end

    it 'uses correct dates in range for multiple version updates' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      v20250224_dir = File.join(temp_dir, 'v20250224')
      v20111101_dir = File.join(temp_dir, 'v20111101')

      FileUtils.mkdir_p(v20250224_dir)
      FileUtils.mkdir_p(v20111101_dir)

      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20250224_package.json'),
        File.join(v20250224_dir, 'package.json')
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20111101_package.json'),
        File.join(v20111101_dir, 'package.json')
      )

      # Execute
      result = ChangelogManager.update('v20250224,v20111101')

      # Verify
      expect(result).to be true
      updated_content = File.read(changelog_path)

      # v20111101 should have date range (prior entry on 2025-01-15)
      expect(updated_content).to include('between 2025-01-15 and 2025-01-28')

      # v20250224 should NOT have date range (no prior entry)
      v20250224_section = updated_content[/## \[3\.0\.0\].*?(?=##|\z)/m]
      expect(v20250224_section).not_to match(/between.*v20250224/)
    end
  end

  describe '.update error handling' do
    it 'raises error when changelog not found' do
      # Execute with non-existent changelog
      expect {
        ChangelogManager.update('v20250224')
      }.to raise_error(/Changelog not found/)
    end

    it 'raises error when package.json not found' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )

      # Execute without creating version directory
      expect {
        ChangelogManager.update('v20250224')
      }.to raise_error(/Package file not found/)
    end

    it 'raises error when package.json is malformed' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      package_dir = File.join(temp_dir, 'v20250224')

      FileUtils.mkdir_p(package_dir)
      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      File.write(
        File.join(package_dir, 'package.json'),
        'invalid json {]'
      )

      # Execute
      expect {
        ChangelogManager.update('v20250224')
      }.to raise_error(JSON::ParserError)
    end

    it 'raises error when version is not in package.json' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      package_dir = File.join(temp_dir, 'v20250224')

      FileUtils.mkdir_p(package_dir)
      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      File.write(
        File.join(package_dir, 'package.json'),
        JSON.generate({ name: '@mx-platform/node' })  # Missing version
      )

      # Execute
      expect {
        ChangelogManager.update('v20250224')
      }.to raise_error(/Could not read version/)
    end

    it 'raises error when changelog has no existing entries' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      package_dir = File.join(temp_dir, 'v20250224')

      FileUtils.mkdir_p(package_dir)
      File.write(
        changelog_path,
        "# Changelog\n\nNo entries here"
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20250224_package.json'),
        File.join(package_dir, 'package.json')
      )

      # Execute
      expect {
        ChangelogManager.update('v20250224')
      }.to raise_error(/Could not find existing changelog entries/)
    end
  end



  describe '.run (CLI entry point)' do
    it 'validates and updates successfully with valid versions' do
      # Setup
      changelog_path = File.join(temp_dir, 'CHANGELOG.md')
      package_dir = File.join(temp_dir, 'v20250224')

      FileUtils.mkdir_p(package_dir)
      FileUtils.cp(
        File.join(fixtures_dir, 'CHANGELOG_sample.md'),
        changelog_path
      )
      FileUtils.cp(
        File.join(fixtures_dir, 'v20250224_package.json'),
        File.join(package_dir, 'package.json')
      )

      # Execute
      expect {
        ChangelogManager.run('v20250224')
      }.to output(/✅ CHANGELOG updated successfully/).to_stdout

      # Verify changelog was updated
      updated_content = File.read(changelog_path)
      expect(updated_content).to include('## [3.0.0] - 2025-01-28 (v20250224 API)')
    end

    it 'exits with error when versions argument is nil' do
      expect {
        ChangelogManager.run(nil)
      }.to output(/Usage: ruby changelog_manager.rb/).to_stdout.and raise_error(SystemExit)
    end

    it 'exits with error when versions argument is empty string' do
      expect {
        ChangelogManager.run('')
      }.to output(/Usage: ruby changelog_manager.rb/).to_stdout.and raise_error(SystemExit)
    end

    it 'exits with error when version is invalid' do
      expect {
        ChangelogManager.run('v99999999')
      }.to output(/❌ Error: Invalid versions/).to_stdout.and raise_error(SystemExit)
    end

    it 'exits with error when any version in list is invalid' do
      expect {
        ChangelogManager.run('v20250224,v99999999')
      }.to output(/❌ Error: Invalid versions/).to_stdout.and raise_error(SystemExit)
    end

    it 'outputs supported versions when argument is missing' do
      expect {
        ChangelogManager.run(nil)
      }.to output(/Supported versions: v20250224, v20111101/).to_stdout.and raise_error(SystemExit)
    end

    it 'outputs supported versions when version is invalid' do
      expect {
        ChangelogManager.run('v99999999')
      }.to output(/Supported versions: v20250224, v20111101/).to_stdout.and raise_error(SystemExit)
    end
  end
end
