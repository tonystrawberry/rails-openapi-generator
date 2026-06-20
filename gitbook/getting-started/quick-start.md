# Quick Start

This page walks you from a fresh gem install to a working OpenAPI document in under five minutes.

## 1. Install the gem

```ruby
# Gemfile
gem "rails-openapi-generator"
```

```sh
bundle install
```

## 2. Run the generator

```sh
bundle exec rake openapi:generate
```

The generator prints a summary and writes the spec:

```
OpenAPI document written to doc/openapi.json
  Processed: 42 endpoints
  Skipped:   1
    - GET /legacy (no backing controller action)
  Warnings:  0
```

The output file is `doc/openapi.json` by default. Re-runs produce byte-identical output — safe to commit and diff in CI.

## 3. Preview the spec

Open it in Redoc (no install needed):

```sh
npx @redocly/cli build-docs doc/openapi.json -o doc/openapi.html
open doc/openapi.html
```

Or use Swagger UI via Docker:

```sh
docker run --rm -p 8081:8080 \
  -e SWAGGER_JSON=/spec/openapi.json \
  -v "$PWD/doc:/spec" swaggerapi/swagger-ui
```

Then visit `http://localhost:8081`.

## 4. Document your first endpoint

Add a YARD comment and some `param!` calls to a controller action:

```ruby
class Api::UsersController < ApplicationController
  # List users
  # Returns all active users ordered by creation date.
  def index
    param! :page,     Integer, default: 1
    param! :per_page, Integer, in: 1..100, default: 25
    # ...
  end
end
```

Re-run `rake openapi:generate`. The `GET /api/users` operation will now have a summary, description, and two query parameters with their constraints.

## 5. Commit the spec to version control

```sh
git add doc/openapi.json
git commit -m "Add generated OpenAPI spec"
```

Add the generation step to your CI pipeline to catch drift:

```yaml
# .github/workflows/ci.yml (example)
- run: bundle exec rake openapi:generate
- run: git diff --exit-code doc/openapi.json
```

## Next step

[Configuration →](configuration.md)
