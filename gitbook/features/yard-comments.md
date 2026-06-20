# Summaries & Descriptions (YARD)

The generator reads YARD-style comments directly above controller action methods and maps them to OpenAPI operation fields.

## Basic usage

```ruby
# Search users
# Returns the users matching the given filters, newest first.
# Results are paginated; use the `page` and `per_page` parameters to navigate.
def index
  # ...
end
```

The first line becomes the OpenAPI `summary`. Every subsequent paragraph becomes the `description`. Both fields are plain strings in the spec — you can include Markdown tables, fenced code blocks, or inline links, and they will pass through verbatim to renderers like Redoc or Swagger UI.

## What gets picked up

| YARD position | OpenAPI field |
|---|---|
| First comment line | `summary` |
| Remaining lines | `description` |

Multi-paragraph descriptions work:

```ruby
# Create a user
#
# Creates a new user and sends a welcome email.
#
# ## Roles
#
# | Role   | Permissions          |
# |--------|----------------------|
# | admin  | all resources        |
# | member | own resources only   |
#
# Returns `422` if validation fails.
def create
  # ...
end
```

## What does NOT get picked up

- `@param` tags — parameters come from `param!` calls (see [Parameters](parameters.md))
- `@return` tags — response schemas come from jbuilder templates or `.schema.json` files
- `@deprecated`, `@since`, and other YARD metadata tags — ignored

The generator intentionally separates human-written prose (YARD) from machine-readable schemas (`param!`, views), so you don't duplicate type information.

## No comment → no summary

If an action has no YARD comment, the `summary` and `description` fields are omitted from the operation. The endpoint is still generated with its parameters and response schema.

## Inherited and concern-level comments

YARD comments are read from the file that defines the action. If an action is defined in a controller concern and mixed in, the comment in the concern file is used. Comments are not inherited from parent class methods when the action is overridden.
