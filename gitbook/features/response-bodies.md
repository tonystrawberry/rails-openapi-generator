# Response Bodies

The generator derives response schemas from four sources, applied in priority order. You can mix sources across different actions in the same app.

## Source 1: jbuilder template

The primary source for JSON responses. The generator statically parses `.json.jbuilder` files using Ruby's `Ripper` AST parser — no code is executed.

```ruby
# app/views/api/users/show.json.jbuilder
json.id         user.id
json.name       user.name
json.email      user.email
json.role       "member"           # literal → carries example value
json.active     true               # literal → carries example value
json.created_at user.created_at
```

→ Object schema with six properties. Literals produce `example` values; method calls on model objects produce `{}` (any schema, since the return type is unknown at parse time).

### Nested objects

```ruby
json.profile do
  json.bio      user.bio
  json.avatar   user.avatar_url
end
```

→ `{ "profile": { "type": "object", "properties": { "bio": {}, "avatar": {} } } }`

### Arrays via `json.array!`

```ruby
json.array! @users do |user|
  json.id   user.id
  json.name user.name
end
```

→ `{ "type": "array", "items": { "type": "object", "properties": { "id": {}, "name": {} } } }`

### `json.extract!`

```ruby
json.extract! user, :id, :name, :email
```

→ Three properties, each typed `{}` (unknown — use a sidecar to add types).

### Partials

```ruby
# app/views/api/users/index.json.jbuilder
json.users @users, partial: "user", as: :user
```

The generator follows the partial reference using Rails' relative-partial convention and merges the partial's schema as the array item schema:

```json
{
  "users": {
    "type": "array",
    "items": { /* schema from _user.json.jbuilder */ }
  }
}
```

Bare partial names (`partial: "user"`) and directory-qualified names (`partial: "api/users/user"`) are both resolved.

## Source 2: Inline `render json:`

When an action renders a literal hash, the hash structure becomes the schema and each value becomes an `example`:

```ruby
render json: { id: 1, role: "member", active: true }, status: :created
```

→ 201 response with:

```json
{
  "type": "object",
  "properties": {
    "id":     { "type": "integer", "example": 1 },
    "role":   { "type": "string",  "example": "member" },
    "active": { "type": "boolean", "example": true }
  }
}
```

## Source 3: Partial recursion

Partials referenced from a template are resolved transitively. A partial can itself reference other partials. Cycles are detected and stopped.

## Source 4: JSON Schema sidecar

Drop a `.schema.json` file next to a view or at the action's view path to override or supplement inference. The sidecar file is loaded verbatim — it is not merged with or modified by the parser.

```
app/views/api/users/_user.schema.json       ← used wherever _user partial resolves
app/views/api/users/show.schema.json        ← used for UsersController#show response
app/views/api/users/create.schema.json      ← used even if there is no .jbuilder file
```

See [JSON Schema Sidecars](../guides/schema-sidecars.md) for the full guide.

## Multi-status responses

When an action has multiple possible render paths, each status code gets its own response entry:

```ruby
def update
  if @user.update(user_params)
    render json: @user, status: :ok
  else
    render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
  end
end
```

→ Two entries: `200` with the user schema, `422` with the errors schema.

If the same status code appears with two distinct schemas (e.g. two different error shapes both returning 422), the schemas are unioned with OpenAPI `oneOf`.

## No view file → empty schema

If no jbuilder template, no inline render literal, and no sidecar exist for an action, the generator emits the response entry with an empty schema (`{}`). You can always add a sidecar to fill it in later.
