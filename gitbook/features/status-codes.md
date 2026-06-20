# Status Codes

The generator reads HTTP status codes from `head`, `render status:`, and `redirect_to` calls in your controller actions and any `before_action` or helper methods they invoke.

## Default conventions

When no explicit status is set, the generator applies HTTP-method conventions:

| Verb | Default status |
|---|---|
| GET | 200 |
| POST | 201 |
| PUT / PATCH | 200 |
| DELETE | 204 (no body) |

## Explicit status on render

```ruby
render json: { ok: true }, status: :created        # → 201
render json: { ok: true }, status: :ok             # → 200
render json: { errors: [...] }, status: 422        # → 422
render json: { errors: [...] }, status: :unprocessable_entity  # → 422
```

Both symbol and integer forms are recognized.

## Head (no body)

```ruby
head :no_content      # → 204, no response body entry
head :ok              # → 200, no response body entry
head :unauthorized    # → 401, no response body entry
```

## Redirect

```ruby
redirect_to root_path                          # → 302
redirect_to root_path, status: :see_other      # → 303
redirect_to root_path, status: :moved_permanently  # → 301
```

Redirect responses produce a response entry with no body schema.

## Multiple status codes from one action

When an action has conditional render paths, all reachable status codes appear in the spec:

```ruby
def show
  @user = User.find_by(id: params[:id])
  if @user
    render json: @user                          # 200
  else
    render json: { error: "not found" }, status: :not_found   # 404
  end
end
```

→ Operation has both a `200` and a `404` response entry.

The generator does not try to prove reachability — it collects every `render`/`head`/`redirect_to` it can see in the action body, helper chain, and applicable `before_action` callbacks. The conservative assumption is that any visible render site is reachable.

## Status codes from before\_action

```ruby
before_action :require_authentication

def require_authentication
  head :unauthorized unless current_user
end
```

Every action that applies `require_authentication` will have a `401` entry in its response list, with no body.

## Status codes from rescue\_from

See [Error Responses](error-responses.md) — `rescue_from` handlers contribute their status codes and schemas to every operation in the controller hierarchy.
