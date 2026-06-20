# Previewing the Spec

After generating `doc/openapi.json`, you can render it as a human-readable HTML page using several free tools.

## Redoc (recommended — no server needed)

```sh
npx @redocly/cli build-docs doc/openapi.json -o doc/openapi.html
open doc/openapi.html
```

`@redocly/cli` builds a self-contained HTML file — no internet connection at read time, easy to commit or attach to a CI artifact.

To serve it with live reload during development:

```sh
npx @redocly/cli preview-docs doc/openapi.json
```

Then open `http://127.0.0.1:8080` in your browser. The page auto-refreshes when the spec file changes.

## Swagger UI (Docker)

```sh
docker run --rm -p 8081:8080 \
  -e SWAGGER_JSON=/spec/openapi.json \
  -v "$PWD/doc:/spec" swaggerapi/swagger-ui
```

Visit `http://localhost:8081`. Swagger UI lets you expand each operation and try requests against a running server.

## Stoplight Elements (web component)

If you want to embed the docs in an existing Rails view:

```html
<!-- app/views/docs/index.html.erb -->
<!DOCTYPE html>
<html>
<head>
  <title>API Docs</title>
  <script src="https://unpkg.com/@stoplight/elements/web-components.min.js"></script>
  <link rel="stylesheet" href="https://unpkg.com/@stoplight/elements/styles.min.css">
</head>
<body>
  <elements-api
    apiDescriptionUrl="/openapi.json"
    router="hash"
    layout="sidebar"
  />
</body>
</html>
```

Then serve the spec file from a controller:

```ruby
# config/routes.rb
get "/openapi.json", to: "docs#spec"
get "/docs",         to: "docs#index"

# app/controllers/docs_controller.rb
class DocsController < ApplicationController
  def spec
    render file: Rails.root.join("doc/openapi.json"), content_type: "application/json"
  end
end
```

## YAML output for readability

If you prefer to read the spec as YAML (easier to diff in PRs):

```ruby
config.output_path = "doc/openapi.yaml"
```

All three viewer tools above accept both JSON and YAML.

## CI artifact

Upload the spec as a CI artifact to review it alongside pull requests:

```yaml
# .github/workflows/ci.yml (example)
- name: Generate OpenAPI spec
  run: bundle exec rake openapi:generate

- name: Upload spec
  uses: actions/upload-artifact@v4
  with:
    name: openapi-spec
    path: doc/openapi.json
```

## Drift detection

Commit the spec to version control and fail CI when it changes unexpectedly:

```yaml
- run: bundle exec rake openapi:generate
- run: git diff --exit-code doc/openapi.json
```

This catches cases where a developer changed a controller or view without regenerating the spec.
