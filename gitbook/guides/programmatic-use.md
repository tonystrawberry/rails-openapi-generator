# Programmatic Use

The generator exposes a Ruby API for use outside of rake or CLI — useful for testing, tooling integration, or dynamic spec serving.

## Generate and write to disk

```ruby
require "rails_openapi_generator"

config = RailsOpenapiGenerator::Configuration.new
config.output_path = "doc/openapi.json"
config.title       = "My API"
config.api_version = "1.0.0"

report = RailsOpenapiGenerator::Generator.new(config).generate
```

`generate` writes the file to `config.output_path` and returns a `GenerationReport`.

## Get the document in memory

```ruby
document = RailsOpenapiGenerator::Generator.new(config).document
# => Hash — the full OpenAPI 3.1 document, not serialized
```

Use this to post-process the document before writing:

```ruby
doc = RailsOpenapiGenerator::Generator.new(config).document

# Add a security scheme
doc["components"] ||= {}
doc["components"]["securitySchemes"] = {
  "bearerAuth" => {
    "type" => "http",
    "scheme" => "bearer",
    "bearerFormat" => "JWT"
  }
}

# Apply it globally
doc["security"] = [{ "bearerAuth" => [] }]

File.write("doc/openapi.json", JSON.pretty_generate(doc))
```

## Reading the generation report

```ruby
report = RailsOpenapiGenerator::Generator.new(config).generate

puts "Processed: #{report.processed_count}"
puts "Skipped:   #{report.skipped_count}"

report.skipped.each do |item|
  puts "  - #{item.verb} #{item.path}: #{item.reason}"
end

report.warnings.each do |warning|
  puts "Warning: #{warning}"
end
```

## Using the default configuration

If you have a `config/initializers/rails_openapi_generator.rb` already, you can use the configured instance directly:

```ruby
generator = RailsOpenapiGenerator::Generator.new(RailsOpenapiGenerator.configuration)
generator.generate
```

## Serving the spec from a controller

```ruby
class Api::DocsController < ApplicationController
  def show
    config = RailsOpenapiGenerator.configuration
    document = RailsOpenapiGenerator::Generator.new(config).document
    render json: document
  end
end
```

Note: generating the spec on every request is slow for large apps. Cache the result:

```ruby
def show
  spec = Rails.cache.fetch("openapi_spec", expires_in: 1.hour) do
    RailsOpenapiGenerator::Generator.new(RailsOpenapiGenerator.configuration).document
  end
  render json: spec
end
```

## RSpec integration

Test that your spec is still valid after changes:

```ruby
# spec/openapi_spec.rb
require "rails_helper"
require "json_schemer"

RSpec.describe "OpenAPI spec" do
  let(:document) do
    config = RailsOpenapiGenerator::Configuration.new
    config.output_path = Rails.root.join("doc/openapi.json").to_s
    RailsOpenapiGenerator::Generator.new(config).document
  end

  it "is valid OpenAPI 3.1" do
    meta_schema = JSONSchemer.openapi31
    errors = meta_schema.validate(document).to_a
    expect(errors).to be_empty, errors.map { |e| e["error"] }.join("\n")
  end

  it "has no generation warnings" do
    config = RailsOpenapiGenerator::Configuration.new
    report = RailsOpenapiGenerator::Generator.new(config).generate
    expect(report.warnings).to be_empty
  end
end
```
