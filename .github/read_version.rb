require "yaml"
config = YAML.load(File.read("openapi/config.yml"))
puts config["npmVersion"]
