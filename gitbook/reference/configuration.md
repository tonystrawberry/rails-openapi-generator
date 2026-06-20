# Configuration Options

Full reference for all settings accepted by `RailsOpenapiGenerator.configure`.

## output\_path

**Type:** `String`
**Default:** `"doc/openapi.json"`

Path where the spec file will be written, relative to the Rails root.

```ruby
config.output_path = "doc/openapi.json"    # JSON
config.output_path = "doc/openapi.yaml"    # YAML
config.output_path = "public/api-spec.yml" # also YAML
```

The format (JSON vs YAML) is inferred from the extension (`.json` → JSON; `.yaml` / `.yml` → YAML). See `format` to override.

---

## format

**Type:** `:json` or `:yaml`
**Default:** inferred from `output_path` extension

```ruby
config.format = :yaml
```

Only set this explicitly when your `output_path` extension does not match the desired format.

---

## title

**Type:** `String`
**Default:** `Rails.application.class.module_parent_name`

Sets `info.title` in the generated document.

```ruby
config.title = "My Store API"
```

---

## api\_version

**Type:** `String`
**Default:** `"1.0.0"`

Sets `info.version` in the generated document. Any string is valid.

```ruby
config.api_version = "2.0.0"
config.api_version = "v2024-01"
```

---

## route\_filter

**Type:** `Proc` (lambda)
**Default:** `nil` (include all routes)

A lambda called with each route object. Return `true` to include, `false` to exclude.

```ruby
config.route_filter = ->(route) { route.path.start_with?("/api/") }
```

The route object exposes:

| Attribute | Example |
|---|---|
| `route.path` | `"/api/users/:id"` |
| `route.verb` | `"GET"` |
| `route.controller` | `"api/users"` |
| `route.action` | `"show"` |

See [Route Filtering](../guides/route-filtering.md) for patterns and examples.

---

## exclude\_source\_paths

**Type:** `Array<String | Regexp>`
**Default:** `[]`

An array of strings or regular expressions matched against the controller's source file path. Any route whose controller file path matches at least one entry is excluded.

```ruby
config.exclude_source_paths = [
  "vendor/",
  "app/controllers/devise/",
  %r{app/controllers/admin/},
]
```

- **String** — substring match
- **Regexp** — matched with `=~`

---

## method\_resolution\_depth

**Type:** `Integer`
**Default:** `5`

Controls how many levels deep the generator follows method calls when tracing helper chains, `before_action` callbacks, and `rescue_from` handlers.

```ruby
config.method_resolution_depth = 5   # default
config.method_resolution_depth = 10  # for deeply nested helpers
config.method_resolution_depth = 2   # to speed up large apps
```

Increasing this allows the generator to find `render`/`head`/`send_file` calls buried deeper in helper hierarchies. Decreasing it speeds up generation at the cost of missing some response sites.

---

## Environment variables (one-off overrides)

These override the configured values for a single rake invocation without touching the initializer:

```sh
rake openapi:generate OUTPUT=tmp/openapi.yaml FORMAT=yaml
```

| Variable | Overrides |
|---|---|
| `OUTPUT` | `output_path` |
| `FORMAT` | `format` |

---

## CLI flags

```sh
bundle exec rails-openapi-generator \
  --rails-root /path/to/app \
  --output doc/openapi.json
```

| Flag | Description |
|---|---|
| `--rails-root PATH` | Path to the Rails application root |
| `--output PATH` | Output file path (overrides `config.output_path`) |
