# Parameters

The generator extracts parameters from `param!` calls (the `rails_param` DSL) in your controller actions. Query parameters are produced for GET/DELETE routes; request body parameters are produced for POST/PUT/PATCH routes.

## Query parameters

```ruby
def index
  param! :query,    String,  blank: false, description: "Free-text search"
  param! :page,     Integer, default: 1
  param! :per_page, Integer, in: 1..100, default: 25
  param! :status,   String,  in: %w[active archived]
end
```

Produces three query parameters on `GET /users`:

```json
{
  "parameters": [
    {
      "name": "query",
      "in": "query",
      "description": "Free-text search",
      "schema": { "type": "string" }
    },
    {
      "name": "page",
      "in": "query",
      "schema": { "type": "integer", "default": 1 }
    },
    {
      "name": "per_page",
      "in": "query",
      "schema": { "type": "integer", "minimum": 1, "maximum": 100, "default": 25 }
    },
    {
      "name": "status",
      "in": "query",
      "schema": { "type": "string", "enum": ["active", "archived"] }
    }
  ]
}
```

## Path parameters

Path segments defined in your routes (e.g. `:id`, `:user_id`) become path parameters automatically. No `param!` call is needed:

```ruby
# routes.rb
resources :users
# → GET /users/:id  automatically gets  { "name": "id", "in": "path", "required": true }
```

If you want to add a description or type constraint to a path segment, add a matching `param!`:

```ruby
def show
  param! :id, Integer, required: true, description: "User's primary key"
end
```

## Request body (POST / PUT / PATCH)

On mutating verbs, top-level `param!` calls become `requestBody` properties instead of query parameters:

```ruby
def create
  param! :name,  String, required: true, description: "Display name"
  param! :email, String, required: true, format: /.+@.+/
  param! :role,  String, in: %w[admin member]
end
```

Produces:

```json
{
  "requestBody": {
    "required": true,
    "content": {
      "application/json": {
        "schema": {
          "type": "object",
          "required": ["name", "email"],
          "properties": {
            "name":  { "type": "string", "description": "Display name" },
            "email": { "type": "string", "pattern": ".+@.+" },
            "role":  { "type": "string", "enum": ["admin", "member"] }
          }
        }
      }
    }
  }
}
```

## Nested parameters

Use a block with `Hash` to describe nested objects:

```ruby
param! :address, Hash, required: true do |a|
  a.param! :street, String, required: true
  a.param! :city,   String, required: true
  a.param! :zip,    String, required: true, format: /\A\d{5}\z/
end
```

Nesting is unlimited:

```ruby
param! :landing_page_setting, Hash, required: true do |h|
  h.param! :downloadable, :boolean, required: true, description: "Default downloadable flag"
  h.param! :sections, Hash, required: false do |s|
    s.param! :logo, Hash, required: false do |logo|
      logo.param! :visible, :boolean, required: true
    end
  end
end
```

## Type mapping

| `param!` type | OpenAPI `type` |
|---|---|
| `String` | `string` |
| `Integer` | `integer` |
| `Float` | `number` |
| `Hash` | `object` |
| `Array` | `array` |
| `:boolean` | `boolean` |
| `TrueClass` / `FalseClass` | `boolean` |

## Constraint mapping

| `param!` constraint | OpenAPI keyword |
|---|---|
| `in: %w[a b c]` | `enum` |
| `in: 1..100` | `minimum` / `maximum` |
| `format: /regex/` | `pattern` |
| `required: true` | adds to `required` array |
| `default: value` | `default` |
| `blank: false` | `minLength: 1` (strings) |

## The `description` option

Pass `description:` to any `param!` call to attach a description at the parameter level:

```ruby
param! :sort, String, in: %w[asc desc], description: "Sort direction"
```

→ `"description": "Sort direction"` appears on the parameter, not just in the summary.
