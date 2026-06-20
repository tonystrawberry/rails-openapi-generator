# ドキュメントのプレビュー

`doc/openapi.json`を生成したら、いくつかの無料ツールで人間が読みやすいHTMLページとしてレンダリングできます。

## Redoc（推奨 — サーバー不要）

```sh
npx @redocly/cli build-docs doc/openapi.json -o doc/openapi.html
open doc/openapi.html
```

`@redocly/cli`は自己完結したHTMLファイルを生成します。読み込み時にインターネット接続は不要で、CIアーティファクトとしてコミットまたは添付しやすいです。

開発中にライブリロードで確認するには:

```sh
npx @redocly/cli preview-docs doc/openapi.json
```

ブラウザで`http://127.0.0.1:8080`を開きます。specファイルが変更されるとページが自動更新されます。

## Swagger UI（Docker）

```sh
docker run --rm -p 8081:8080 \
  -e SWAGGER_JSON=/spec/openapi.json \
  -v "$PWD/doc:/spec" swaggerapi/swagger-ui
```

`http://localhost:8081`にアクセスします。Swagger UIでは各オペレーションを展開して、実行中のサーバーに対してリクエストを試せます。

## Stoplight Elements（Webコンポーネント）

既存のRailsビューにドキュメントを埋め込む場合:

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

コントローラからspecファイルを配信します。

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

## 読みやすさのためのYAML出力

specをYAMLで読みたい場合（PRのdiffがより見やすくなります）:

```ruby
config.output_path = "doc/openapi.yaml"
```

上記3つのビューアはJSONとYAMLどちらにも対応しています。

## CIアーティファクト

プルリクエストと一緒にspecをCIアーティファクトとしてアップロードできます。

```yaml
# .github/workflows/ci.yml（例）
- name: Generate OpenAPI spec
  run: bundle exec rake openapi:generate

- name: Upload spec
  uses: actions/upload-artifact@v4
  with:
    name: openapi-spec
    path: doc/openapi.json
```

## ドリフト検知

specをバージョン管理にコミットして、予期しない変更があった場合にCIを失敗させます。

```yaml
- run: bundle exec rake openapi:generate
- run: git diff --exit-code doc/openapi.json
```

これにより、開発者がコントローラやビューを変更してspecを再生成し忘れたケースを検知できます。
