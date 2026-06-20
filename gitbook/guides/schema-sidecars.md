# JSON Schema Sidecars

A JSON Schema sidecar is a `.schema.json` file placed next to a view or at the action's view path. When present, it replaces the generator's inferred schema with your explicitly written one.

Sidecars are the escape hatch for cases where static inference can't reach — conditional fields, polymorphic types, deeply typed `extract!` calls, or schemas you want to own in full.

## Placement

| File location | When it applies |
|---|---|
| `app/views/api/users/show.schema.json` | `UsersController#show` response |
| `app/views/api/users/create.schema.json` | `UsersController#create` response |
| `app/views/api/users/_user.schema.json` | Wherever `_user` partial is resolved |

The naming convention mirrors the view file — same directory, same base name, `.schema.json` extension. For partials, prefix the base name with an underscore.

## Basic example

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["id", "email"],
  "properties": {
    "id":    { "type": "integer", "minimum": 1, "example": 42 },
    "email": { "type": "string",  "format": "email", "example": "alice@example.com" },
    "role":  { "type": "string",  "enum": ["admin", "member"] },
    "name":  { "type": "string",  "example": "Alice" }
  }
}
```

Drop this at `app/views/api/users/show.schema.json` and the generator uses it verbatim for the `UsersController#show` 200 response, ignoring `show.json.jbuilder` entirely.

## Using $defs for shared types

You can define reusable sub-schemas with `$defs` and reference them with `$ref`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$defs": {
    "Address": {
      "type": "object",
      "required": ["street", "city"],
      "properties": {
        "street": { "type": "string" },
        "city":   { "type": "string" },
        "zip":    { "type": "string", "pattern": "^\\d{5}$" }
      }
    }
  },
  "type": "object",
  "properties": {
    "id":      { "type": "integer" },
    "billing": { "$ref": "#/$defs/Address" },
    "shipping":{ "$ref": "#/$defs/Address" }
  }
}
```

The generator hoists `$defs` to the top-level OpenAPI `components/schemas` section and rewrites `$ref` paths accordingly — so a reference that starts as `#/$defs/Address` inside the sidecar file becomes `#/components/schemas/Address` in the final spec.

### Cross-file $ref

Reference a definition from another sidecar file:

```json
{
  "type": "object",
  "properties": {
    "user":    { "$ref": "app/views/api/users/_user.schema.json#/$defs/UserSummary" },
    "comment": { "$ref": "app/views/api/comments/_comment.schema.json" }
  }
}
```

The generator resolves relative paths from the Rails root. Referenced files are loaded, their `$defs` are hoisted, and `$ref` values are rewritten to point at the hoisted component.

## Sidecar without a view file

A sidecar can exist even when there is no corresponding `.json.jbuilder` template — useful when the action renders inline JSON or when you want to override an inherited partial's schema for just one action:

```
app/views/api/users/bulk_create.schema.json   ← no bulk_create.json.jbuilder needed
```

## Error handling

If a sidecar file contains malformed JSON:

- The generator emits a warning in the generation report
- It falls back to the inferred schema for that action
- Generation continues — it never raises

```
Warnings:
  - app/views/api/users/show.schema.json: invalid JSON — falling back to inferred schema
```

## When to use a sidecar vs. improving the template

Use a sidecar when:

- The jbuilder template uses `extract!` and you want precise types for individual properties
- The response schema is conditional or polymorphic (e.g. `oneOf` two shapes based on `type` field)
- You want to add `format`, `minimum`, `maximum`, `pattern`, or other constraints that jbuilder can't express
- There is no jbuilder template (inline JSON render or external source)

Stick with inference when:

- The template is simple and literals already provide good `example` values
- You don't want to maintain a parallel schema file

## Validating sidecars

Use a JSON Schema validator to check your sidecars before committing:

```sh
npx ajv validate -s https://json-schema.org/draft/2020-12/schema -d app/views/**/*.schema.json
```
