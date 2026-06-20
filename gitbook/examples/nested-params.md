# Example: Nested Parameters

This example shows how to document complex request bodies with deeply nested `param!` blocks — common for settings objects, multi-part forms, and structured data APIs.

## Use case: landing page settings

A settings endpoint that accepts a nested configuration object:

```ruby
# app/controllers/api/settings_controller.rb
class Api::SettingsController < ApplicationController
  # Update landing page settings
  def update
    param! :landing_page_setting, Hash, required: true do |h|
      h.param! :downloadable, :boolean, required: true,
               description: "Whether content is downloadable by default"

      h.param! :background_color, String, required: false,
               format: /\A#[0-9a-fA-F]{6}\z/,
               description: "Hex color code, e.g. #ffffff"

      h.param! :sections, Hash, required: false do |s|
        s.param! :hero, Hash, required: false do |hero|
          hero.param! :title,    String,   required: true
          hero.param! :subtitle, String,   required: false
          hero.param! :visible,  :boolean, required: true
        end

        s.param! :logo, Hash, required: false do |logo|
          logo.param! :url,     String,   required: true,  format: URI::DEFAULT_PARSER.make_regexp
          logo.param! :alt,     String,   required: false, description: "Alt text for accessibility"
          logo.param! :visible, :boolean, required: true
        end
      end
    end

    # ...
    head :ok
  end
end
```

## Generated requestBody schema

```json
{
  "requestBody": {
    "required": true,
    "content": {
      "application/json": {
        "schema": {
          "type": "object",
          "required": ["landing_page_setting"],
          "properties": {
            "landing_page_setting": {
              "type": "object",
              "required": ["downloadable"],
              "properties": {
                "downloadable": {
                  "type": "boolean",
                  "description": "Whether content is downloadable by default"
                },
                "background_color": {
                  "type": "string",
                  "pattern": "\\A#[0-9a-fA-F]{6}\\z",
                  "description": "Hex color code, e.g. #ffffff"
                },
                "sections": {
                  "type": "object",
                  "properties": {
                    "hero": {
                      "type": "object",
                      "required": ["title", "visible"],
                      "properties": {
                        "title":    { "type": "string" },
                        "subtitle": { "type": "string" },
                        "visible":  { "type": "boolean" }
                      }
                    },
                    "logo": {
                      "type": "object",
                      "required": ["url", "visible"],
                      "properties": {
                        "url":     { "type": "string" },
                        "alt":     { "type": "string", "description": "Alt text for accessibility" },
                        "visible": { "type": "boolean" }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

## Key points demonstrated

### :boolean shorthand

```ruby
h.param! :downloadable, :boolean, required: true
```

The `:boolean` symbol (instead of `TrueClass`/`FalseClass`) maps to `"type": "boolean"`. Both forms work.

### Arbitrary nesting depth

The `sections → hero` and `sections → logo` paths are three levels deep inside the top-level `landing_page_setting`. There is no configured limit on nesting depth.

### required at each level

`required: true` at each level of nesting adds the key to the `required` array of its parent object — not the root request body's `required`. The generator tracks the nesting context correctly.

### description propagation

`description:` on any `param!` call appears on that specific property, at whatever depth it is.

## Array of objects

When a body parameter is an array of structured objects, use `Array` as the type and a nested block:

```ruby
param! :items, Array, required: true do |item|
  item.param! :product_id, Integer, required: true
  item.param! :quantity,   Integer, required: true, in: 1..999
  item.param! :note,       String,  required: false
end
```

→ `items` becomes `{ "type": "array", "items": { "type": "object", "required": ["product_id", "quantity"], "properties": { ... } } }`.

## Mixing body and path parameters

Path segments are always path parameters, regardless of whether they appear in `param!` calls. Body params are always `param!` calls on POST/PUT/PATCH:

```ruby
# PUT /api/users/:id/settings
def update_settings
  # :id comes from the route → becomes a path parameter automatically
  param! :theme, String, in: %w[light dark], description: "UI theme preference"
end
```

→ One path parameter (`id`) and one request body property (`theme`).
