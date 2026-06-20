# Route Filtering

By default, the generator processes every route in your Rails application. Use `route_filter` and `exclude_source_paths` to narrow the output.

## route\_filter

A lambda called once per route. Return `false` to exclude the route from the spec.

```ruby
RailsOpenapiGenerator.configure do |config|
  config.route_filter = ->(route) { route.path.start_with?("/api/") }
end
```

### The route object

The lambda receives an object with these attributes:

| Attribute | Type | Example |
|---|---|---|
| `route.path` | String | `"/api/users/:id"` |
| `route.verb` | String | `"GET"` |
| `route.controller` | String | `"api/users"` |
| `route.action` | String | `"show"` |

### Common patterns

```ruby
# Include only /api/ namespace
config.route_filter = ->(r) { r.path.start_with?("/api/") }

# Exclude health-check and internal routes
config.route_filter = ->(r) {
  !r.path.start_with?("/health", "/internal/", "/sidekiq")
}

# Include only specific verbs
config.route_filter = ->(r) { %w[GET POST PUT PATCH DELETE].include?(r.verb) }

# Exclude routes without a controller (mounted engines, etc.)
config.route_filter = ->(r) { r.controller.present? }

# Combine: only /api/ routes, excluding webhooks
config.route_filter = ->(r) {
  r.path.start_with?("/api/") && !r.path.include?("/webhooks/")
}
```

## exclude\_source\_paths

An array of strings or regular expressions matched against the controller's source **file path**. Any controller whose source file path matches at least one entry is excluded — all of its routes are skipped.

```ruby
RailsOpenapiGenerator.configure do |config|
  config.exclude_source_paths = [
    "vendor/",                          # third-party gems mounted as engines
    "app/controllers/devise/",          # Devise-generated controllers
    %r{app/controllers/admin/},         # regex: admin namespace
    %r{/legacy/},                       # regex: anything under a legacy/ folder
  ]
end
```

### Strings vs. regexps

- **String** — substring match against the full file path
- **Regexp** — matched with `=~` against the full file path

```ruby
# String: matches any path containing "vendor/"
"vendor/"

# Regexp: matches paths like app/controllers/v1/admin/users_controller.rb
%r{/admin/}
```

## Combining both filters

`route_filter` and `exclude_source_paths` are applied together — both must pass for a route to be included. Use `route_filter` for path-based rules and `exclude_source_paths` for file-based rules:

```ruby
RailsOpenapiGenerator.configure do |config|
  # Only API paths
  config.route_filter = ->(r) { r.path.start_with?("/api/") }
  # But exclude Devise and legacy controllers regardless of path
  config.exclude_source_paths = ["app/controllers/devise/", %r{/legacy/}]
end
```

## One-off filter at the command line

```sh
rake openapi:generate OUTPUT=tmp/users-only.json FILTER=/api/users
```

`FILTER` is a path prefix — it overrides `route_filter` for that single run.

## Checking what will be generated

Run with `--dry-run` (CLI) to see which routes would be included without writing the file:

```sh
bundle exec rails-openapi-generator --rails-root . --dry-run
```

Or inspect the generation report after a normal run — it lists skipped routes with the reason.
