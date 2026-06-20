# HTML Pages & File Downloads

Not every endpoint returns JSON. The generator recognizes HTML page renders and file download responses, and classifies them accordingly in the spec.

## HTML pages

When an action renders a template that resolves to an `.html.*` view file, the response is classified as an HTML page response:

```ruby
class PagesController < ApplicationController
  def home
    render :home   # → resolves to app/views/pages/home.html.erb
  end
end
```

→ Response entry with:

- `content-type`: `text/html`
- OpenAPI tag: `"HTML Pages"`
- Extension: `x-renders-html: true`
- No body schema (HTML is not machine-readable)

HTML page operations are grouped under a separate `"HTML Pages"` tag in rendered documentation, making them easy to distinguish from API endpoints.

## File downloads

When an action calls `send_file` or `send_data` (directly or via a helper wrapper), the response is classified as a file download:

```ruby
def download
  send_file Rails.root.join("storage", params[:filename]),
            disposition: :attachment
end
```

→ Response entry with:

- `content-type`: `application/octet-stream`
- OpenAPI tag: `"File Downloads"`
- Extension: `x-sends-file: true`
- No body schema

### Helper wrappers

The generator follows `send_file`/`send_data` calls up to `method_resolution_depth` levels deep:

```ruby
def export
  deliver_csv_attachment("users.csv", User.all.to_csv)
end

private

def deliver_csv_attachment(filename, content)
  send_data content, filename: filename, type: "text/csv", disposition: :attachment
end
```

→ `export` is classified as a file download even though `send_data` is inside a helper.

## Mixed responses (`respond_to`)

When an action uses `respond_to` to serve multiple content types, all active branches are captured under one status code:

```ruby
def show
  respond_to do |format|
    format.json { render json: @user }
    format.html
  end
end
```

→ One `200` response entry with two content-type entries: `application/json` (with schema) and `text/html`.

## Redirects

See [Status Codes → Redirect](status-codes.md#redirect) — redirects produce a response entry with the appropriate 3xx status code and no body schema.
