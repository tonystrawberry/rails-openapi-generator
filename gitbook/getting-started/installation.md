# Installation

## Requirements

- Ruby 3.0+
- Rails 7.0+
- [`rails_param`](https://github.com/nicolasblanco/rails_param) gem (optional — only needed if you use `param!` for parameter documentation)

## Add to your Gemfile

```ruby
# Gemfile
gem "rails-openapi-generator"
```

Then install:

```sh
bundle install
```

The gem registers a Railtie automatically. No `require` statement is needed in your code.

## Verify the rake task is available

```sh
bundle exec rake -T openapi
# rake openapi:generate  # Generate OpenAPI 3.1 spec
```

If the task does not appear, ensure `railties` is loading your gem. In engines or non-standard setups, you may need to call `require "rails_openapi_generator"` explicitly before the task registration fires.

## Optional: JSON or YAML output

The output format is inferred from the file extension you configure in `output_path`. JSON is the default; no extra gems are required for either format — Rails ships both `json` and `yaml` in its stdlib dependencies.

## Next step

[Quick Start →](quick-start.md)
