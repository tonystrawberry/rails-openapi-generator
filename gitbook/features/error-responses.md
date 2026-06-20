# Error Responses

The generator automatically discovers `rescue_from` declarations and the render calls inside their handlers, then adds those response entries to every operation in the controller hierarchy.

## Basic example

```ruby
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found
    render json: { error: { code: "NOT_FOUND", message: "Record not found" } },
           status: :not_found
  end
end
```

Every action that inherits from `ApplicationController` will have a `404` entry with that exact body schema — without you adding anything to individual actions.

## Multiple rescue\_from handlers

```ruby
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound,    with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid,     with: :render_unprocessable
  rescue_from Pundit::NotAuthorizedError,      with: :render_forbidden

  private

  def render_not_found
    render json: { error: { code: "NOT_FOUND" } }, status: :not_found
  end

  def render_unprocessable
    render json: { error: { code: "INVALID", details: [] } }, status: :unprocessable_entity
  end

  def render_forbidden
    render json: { error: { code: "FORBIDDEN" } }, status: :forbidden
  end
end
```

→ Every inheriting action gets 404, 422, and 403 entries.

## Helper argument propagation

When the handler delegates to a helper method with literal arguments, the generator traces argument values through the call chain:

```ruby
rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

def render_forbidden
  render_error(status: :forbidden, code: "FORBIDDEN", message: "Access denied")
end

def render_error(status:, code:, message:)
  render json: { error: { code: code, message: message } }, status: status
end
```

The generator binds `status: :forbidden`, `code: "FORBIDDEN"`, and `message: "Access denied"` from the call site into `render_error`'s parameters, so it can resolve the `render` call two levels deep. The resulting response entry has:

```json
{
  "403": {
    "description": "403",
    "content": {
      "application/json": {
        "schema": {
          "type": "object",
          "properties": {
            "error": {
              "type": "object",
              "properties": {
                "code":    { "type": "string", "example": "FORBIDDEN" },
                "message": { "type": "string", "example": "Access denied" }
              }
            }
          }
        }
      }
    }
  }
}
```

## Concerns

`rescue_from` declarations in controller concerns are picked up if the concern is included in the controller chain. The generator walks the ancestor list the same way Ruby does.

## Scoped rescue\_from (per-controller)

A `rescue_from` defined on a non-base controller only applies to actions in that controller and its subclasses:

```ruby
class Api::PaymentsController < ApplicationController
  rescue_from Stripe::CardError, with: :render_card_error

  def render_card_error(e)
    render json: { error: { code: "CARD_ERROR", detail: e.message } }, status: :payment_required
  end
end
```

→ Only actions in `Api::PaymentsController` get the `402` entry.

## Deduplication

If an action's own render sites and the `rescue_from` handlers produce the same status code with the same schema, the entry appears once. Identical schemas under the same status code are always deduplicated.
