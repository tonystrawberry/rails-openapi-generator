# rails-openapi-generator

Generate an OpenAPI 3.1 document for a Rails app by static source analysis. No controller code is executed.

## Documentation

The full documentation is published on **[GitBook](https://tonystrawberry.gitbook.io/rails-openapi-generator)** and is the single source of truth for this project.

| Language | URL |
|---|---|
| English | https://tonystrawberry.gitbook.io/rails-openapi-generator |
| 日本語 | https://tonystrawberry.gitbook.io/rails-openapi-generator-ja |

Documentation source lives in this repository:

- [`gitbook/`](gitbook/) — English pages
- [`gitbook-ja/`](gitbook-ja/) — Japanese pages

This README is a quick reference only. For installation guides, configuration options, feature deep-dives, and worked examples, refer to the GitBook site above.

## Install

```ruby
# Gemfile
gem "rails-openapi-generator"
```

```sh
bundle install
bundle exec rake openapi:generate
```

Output lands at `doc/openapi.json`. Re-runs are byte-identical given the same source.

## Configure (optional)

```ruby
# config/initializers/rails_openapi_generator.rb
RailsOpenapiGenerator.configure do |config|
  config.output_path  = "doc/openapi.yaml"        # default: doc/openapi.json
  config.title        = "My Store API"            # default: app name
  config.api_version  = "2.0.0"                    # default: "1.0.0"
  config.route_filter = ->(route) { route.path.start_with?("/api/") }
  config.exclude_source_paths = ["vendor/", %r{app/controllers/legacy/}]
end
```

| Setting | Default |
|---|---|
| `output_path` | `doc/openapi.json` |
| `format` | inferred from extension (`:json` / `:yaml`) |
| `title` | app name |
| `api_version` | `"1.0.0"` |
| `route_filter` | include all |
| `exclude_source_paths` | `[]` (substrings + regexps; matches controller source path) |
| `method_resolution_depth` | `5` |

## Summary & description — from YARD comments

```ruby
# Search users
# Returns the users matching the given filters, newest first.
def index; end
```

→ `summary: "Search users"`, `description: "Returns the users matching the given filters, newest first."`

Multi-paragraph, markdown tables, fenced code — all passed through verbatim.

## Parameters — from `param!`

```ruby
def index
  param! :query,    String,  blank: false, description: "Free-text search"
  param! :per_page, Integer, in: 1..100
end
```

→ Two query parameters on `GET`. `description` lifts to the parameter level. Path segments (`:id`) become path params automatically.

### Request body (POST/PUT/PATCH)

```ruby
def create
  param! :name,  String,  required: true, description: "Display name"
  param! :email, String,  required: true, format: /.+@.+/
  param! :role,  String,  in: %w[admin member]
end
```

→ `requestBody` with `{ name, email, role }`, `required: [name, email]`, `role.enum: [admin, member]`.

### Nested body

```ruby
param! :landing_page_setting, Hash, required: true do |h|
  h.param! :downloadable, :boolean, required: true, description: "Default downloadable flag"
  h.param! :sections,     Hash,     required: false do |s|
    s.param! :logo, Hash, required: false do |logo|
      logo.param! :visible, :boolean, required: true
    end
  end
end
```

→ Nested `properties` tree with descriptions at every level. `:boolean` symbol shorthand recognized.

## Response body — four sources

### 1. jbuilder template

```ruby
# app/views/api/users/_user.json.jbuilder
json.extract! user, :id, :name, :email
json.role "member"          # → { type: string, example: "member" }
json.profile do
  json.bio user.bio
end
```

→ Object schema with nested `profile`. Literal values carry `example`. Property names from `extract!` use `{}` (any).

### 2. Inline `render json:`

```ruby
render json: { id: 1, role: "member", active: true }, status: :created
```

→ 201 entry with `{ id: integer/example=1, role: string/example="member", active: boolean/example=true }`.

### 3. Partial recursion

```ruby
# app/views/api/users/index.json.jbuilder
json.users @users, partial: "user", as: :user

# Renders against _user.json.jbuilder (Rails relative-partial convention)
```

→ `{ users: { type: array, items: <_user schema> } }`.

### 4. JSON Schema sidecar (override / declare richer types)

Drop a `.schema.json` file next to the template OR at the action's view path:

```text
app/views/api/users/_user.schema.json            # used wherever the partial resolves
app/views/api/users/show.schema.json             # used as the action's response schema
app/views/api/users/create.schema.json           # used even with no .json.jbuilder (inline render or no view)
```

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["id", "email"],
  "properties": {
    "id":    { "type": "integer", "minimum": 1, "example": 42 },
    "email": { "type": "string",  "format": "email", "example": "alice@example.com" },
    "role":  { "type": "string",  "enum": ["admin", "member"] }
  }
}
```

→ Loaded verbatim, replaces the parser's inference. Malformed JSON → warning, fallback to inference (never raises).

## Status codes

Read from `head` and `render status:`. When unset, the HTTP-method convention applies:

| Verb | Status |
|---|---|
| GET / PUT / PATCH | 200 |
| POST | 201 |
| DELETE | 204 (no body) |

```ruby
head :no_content                                   # → 204, no body
render json: { ok: true }, status: :created        # → 201
redirect_to root_path, status: :see_other          # → 303 redirect, no body
send_file path                                      # → file_download
```

## Error responses — from `rescue_from`

`rescue_from` declarations on the controller chain (including concerns) contribute response entries automatically:

```ruby
# ApplicationController
rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

def render_not_found
  render json: { error: { code: "NOT_FOUND" } }, status: :not_found
end
```

→ Every operation in inheriting controllers gains a `404` entry with the literal body schema.

### Helper argument propagation

Literal args at the call site are bound to the helper's params, so:

```ruby
rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

def render_forbidden
  render_error(status: :forbidden, code: "FORBIDDEN", message: "...")
end

def render_error(status:, code:, message:)
  render json: { error: { code: code, message: message } }, status: status
end
```

→ `403` entry with the right schema, even though the `render` is two levels deep.

## HTML pages & file downloads

| Signal | Classification |
|---|---|
| `render :template` resolving to `.html.*` | `html_page` — `text/html`, tag `"HTML Pages"`, `x-renders-html: true` |
| `send_file` / `send_data` (direct or via helper wrapper) | `file_download` — `application/octet-stream`, tag `"File Downloads"`, `x-sends-file: true` |
| `respond_to do \|f\|; f.json; f.html; end` | Multi-content entry under one status |

Wrapper helpers are followed up to `method_resolution_depth` (default 5).

## Run

```sh
rake openapi:generate                                          # writes config.output_path
rake openapi:generate OUTPUT=tmp/openapi.yaml FORMAT=yaml      # one-off override

rails-openapi-generator --rails-root . --output doc/openapi.json   # CLI equivalent
```

Prints a summary:

```text
OpenAPI document written to doc/openapi.json
  Processed: 42 endpoints
  Skipped:   1
    - GET /legacy (no backing controller action)
  Warnings:  0
```

## Preview

```sh
npx @redocly/cli build-docs doc/openapi.json -o doc/openapi.html
open doc/openapi.html
```

Or Swagger UI via Docker:

```sh
docker run --rm -p 8081:8080 \
  -e SWAGGER_JSON=/spec/openapi.json \
  -v "$PWD/doc:/spec" swaggerapi/swagger-ui
# http://localhost:8081
```

## Programmatic use

```ruby
config = RailsOpenapiGenerator::Configuration.new
config.output_path = "doc/openapi.json"

RailsOpenapiGenerator::Generator.new(config).generate           # writes to disk + returns Report
document = RailsOpenapiGenerator::Generator.new(config).document # in-memory Hash
```

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT.
