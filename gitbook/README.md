# rails-openapi-generator

Generate a complete OpenAPI 3.1 document for your Rails application through **static source analysis** — no controller code is executed, no test server is spun up.

The gem reads your route set, parses your controllers and jbuilder templates with Ruby's `Ripper` AST parser, and writes a byte-identical spec file every time.

## What it produces

A single JSON or YAML file — `doc/openapi.json` by default — containing every route as an OpenAPI 3.1 operation with:

- **Parameters** extracted from `param!` (rails\_param) declarations
- **Request bodies** inferred from POST/PUT/PATCH `param!` blocks
- **Response schemas** derived from jbuilder templates, inline `render json:`, or `.schema.json` sidecars
- **Status codes** read from `head`, `render status:`, and `redirect_to` calls
- **Error responses** from `rescue_from` declarations
- **Summaries and descriptions** from YARD comments on controller actions

## Why static analysis

Static analysis means the spec is always in sync with your source code, not with what ran last. There is no flaky "record mode", no running migrations, no seeding a test database. Run `rake openapi:generate` from CI and diff the output.

## Quick look

```sh
# Gemfile
gem "rails-openapi-generator"

bundle install
bundle exec rake openapi:generate
# → doc/openapi.json
```

See [Installation](getting-started/installation.md) to get started.

## Navigation

- **Getting Started** — install, configure, and run your first generation
- **Features** — deep dives into parameters, responses, status codes, and more
- **Guides** — schema sidecars, route filtering, previewing docs, and programmatic use
- **Reference** — complete configuration option listing
- **Examples** — end-to-end worked examples with real controller + view code
