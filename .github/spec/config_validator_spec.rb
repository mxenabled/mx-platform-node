require 'rspec'
require_relative '../config_validator'

describe ConfigValidator do
  subject { ConfigValidator.validate!(path, api_version) }

  let(:path) { 'config-test.yml' }
  let(:api_version) { 'v20111101' }
  let(:yaml_content) { "---\nnpmVersion: 2.0.0\napiVersion: v20111101\n" }
  let(:file_exists) { true }

  before do
    allow(File).to receive(:exist?).with(path).and_return(file_exists)
    allow(File).to receive(:read).with(path).and_return(yaml_content)
  end


  describe 'with valid configurations' do
    let(:yaml_content) { "---\nnpmVersion: 2.0.0\napiVersion: v20111101\n" }
    let(:api_version) { 'v20111101' }

    it 'validates v20111101 config with major version 2' do
      expect(subject).to be true
    end

    context 'with v20250224' do
      let(:yaml_content) { "---\nnpmVersion: 3.0.0\napiVersion: v20250224\n" }
      let(:api_version) { 'v20250224' }

      it 'validates v20250224 config with major version 3' do
        expect(subject).to be true
      end
    end

    context 'with different minor and patch versions' do
      context 'for v20111101' do
        let(:yaml_content) { "---\nnpmVersion: 2.1.5\napiVersion: v20111101\n" }
        let(:api_version) { 'v20111101' }

        it 'validates with minor.patch variations' do
          expect(subject).to be true
        end
      end

      context 'for v20250224' do
        let(:yaml_content) { "---\nnpmVersion: 3.2.1\napiVersion: v20250224\n" }
        let(:api_version) { 'v20250224' }

        it 'validates with minor.patch variations' do
          expect(subject).to be true
        end
      end
    end
  end

  describe 'with invalid API version' do
    let(:api_version) { 'v99999999' }

    it 'raises error when API version is not supported' do
      expect { subject }.to raise_error(/Invalid API version: v99999999/)
    end

    it 'includes list of supported versions in error message' do
      expect { subject }.to raise_error(/Supported versions: v20111101, v20250224/)
    end
  end

  describe 'with missing config file' do
    let(:file_exists) { false }

    it 'raises error when config file does not exist' do
      expect { subject }.to raise_error(/Config file not found: #{Regexp.escape(path)}/)
    end
  end

  describe 'with semantic versioning errors' do
    let(:yaml_content) { "---\nnpmVersion: 3.0.0\napiVersion: v20111101\n" }
    let(:api_version) { 'v20111101' }

    it 'raises descriptive error with all required details' do
      expect { subject }.to raise_error(/Semantic versioning error.*must use npm major version 2.*found 3.*Update config with correct major version: 2\.x\.x/m)
    end
  end

  describe 'with malformed config file' do
    let(:yaml_content) { "---\n  invalid: yaml: invalid syntax:" }

    it 'raises error when YAML is syntactically invalid' do
      expect { subject }.to raise_error(/Config file syntax error|does not contain valid YAML/)
    end
  end

  describe 'with missing npmVersion field' do
    let(:yaml_content) { "---\ngeneratorName: typescript-axios\napiVersion: v20111101\n" }
    let(:api_version) { 'v20111101' }

    it 'raises error when npmVersion is not in config' do
      expect { subject }.to raise_error(/missing npmVersion field/)
    end
  end

  describe 'behavior across all supported versions' do
    ConfigValidator::SUPPORTED_VERSIONS.each do |api_ver, expected_major|
      describe "for #{api_ver}" do
        let(:api_version) { api_ver }

        it 'allows any minor.patch combination for major version' do
          [0, 1, 5, 10].each do |minor|
            [0, 1, 5, 10].each do |patch|
              version = "#{expected_major}.#{minor}.#{patch}"

              allow(File).to receive(:read).with(path).and_return("---\nnpmVersion: #{version}\napiVersion: #{api_ver}\n")

              expect { ConfigValidator.validate!(path, api_ver) }.not_to raise_error
            end
          end
        end

        it 'rejects any other major version' do
          wrong_major = expected_major == 2 ? 3 : 2
          version = "#{wrong_major}.0.0"

          allow(File).to receive(:read).with(path).and_return("---\nnpmVersion: #{version}\napiVersion: #{api_ver}\n")

          expect { ConfigValidator.validate!(path, api_ver) }.to raise_error(/Semantic versioning error/)
        end
      end
    end
  end
end
