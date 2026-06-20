# Configuration

Configuration lives in an initializer. All settings are optional.

```ruby
# config/initializers/rails_openapi_generator.rb
RailsOpenapiGenerator.configure do |config|
  config.output_path             = "doc/openapi.yaml"
  config.title                   = "My Store API"
  config.api_version             = "2.0.0"
  config.route_filter            = ->(route) { route.path.start_with?("/api/") }
  config.exclude_source_paths    = ["vendor/", %r{app/controllers/legacy/}]
  config.method_resolution_depth = 5
end
```

## Settings at a glance

| Setting | Default | Description |
|---|---|---|
| `output_path` | `"doc/openapi.json"` | Where to write the spec file |
| `format` | inferred from extension | `:json` or `:yaml` |
| `title` | app name | `info.title` in the spec |
| `api_version` | `"1.0.0"` | `info.version` in the spec |
| `route_filter` | include all | Lambda called with each route — return `false` to exclude |
| `exclude_source_paths` | `[]` | Strings or regexps matched against the controller source file path |
| `method_resolution_depth` | `5` | How deep to follow helper/callback chains |

## output\_path and format

```ruby
config.output_path = "doc/openapi.json"   # JSON output
config.output_path = "doc/openapi.yaml"   # YAML output
config.output_path = "doc/openapi.yml"    # also YAML
```

The format is inferred from the extension. You can also set `config.format` explicitly:

```ruby
config.format = :yaml
```

## title and api\_version

These map directly to the OpenAPI `info` object:

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "My Store API",
    "version": "2.0.0"
  }
}
```

## route\_filter

A lambda that receives a route object and returns `true` to include, `false` to exclude. Useful for limiting generation to your API namespace:

```ruby
# Only include routes under /api/
config.route_filter = ->(route) { route.path.start_with?("/api/") }

# Exclude a specific path
config.route_filter = ->(route) { !route.path.start_with?("/internal/") }

# Include only JSON-capable verbs
config.route_filter = ->(route) { %w[GET POST PUT PATCH DELETE].include?(route.verb) }
```

See [Route Filtering](../guides/route-filtering.md) for a detailed guide.

## exclude\_source\_paths

An array of strings or regular expressions matched against the controller source file path. Any controller matching at least one entry is excluded:

```ruby
config.exclude_source_paths = [
  "vendor/",                            # anything under vendor/
  %r{app/controllers/admin/},           # admin namespace
  "app/controllers/devise/",            # Devise controllers
]
```

This is useful for third-party engines or legacy namespaces where you do not control the source.

## method\_resolution\_depth

Controls how many levels deep the gem follows helper method calls and `before_action` callbacks when looking for `render`, `head`, and `send_file` calls:

```ruby
config.method_resolution_depth = 5   # default
```

Increase this if you have deeply nested helper chains. Decrease it to speed up generation for large apps where deep traversal is not needed.

## One-off overrides at the command line

```sh
rake openapi:generate OUTPUT=tmp/openapi.yaml FORMAT=yaml
```

`OUTPUT` and `FORMAT` override the configured values for that single run without touching the initializer.

## CLI equivalent

```sh
bundle exec rails-openapi-generator \
  --rails-root . \
  --output doc/openapi.json
```
