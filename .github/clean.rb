require "fileutils"

# Version-targeted deletion: Deletes specified version directory only
# All workflows must provide version directory parameter

target_dir = ARGV[0]

if target_dir.nil? || target_dir.empty?
  raise "Error: Version directory parameter required. Usage: ruby clean.rb <version_dir>"
end

# Delete only the specified directory
target_path = "#{::Dir.pwd}/#{target_dir}"
if ::File.exist?(target_path)
  ::FileUtils.rm_rf(target_path)
  puts "Deleted: #{target_path}"
else
  puts "Directory not found (will be created during generation): #{target_path}"
end
