# 設定

設定はイニシャライザに記述します。すべての設定は任意です。

```ruby
# config/initializers/rails_openapi_generator.rb
RailsOpenapiGenerator.configure do |config|
  config.output_path             = "doc/openapi.yaml"
  config.title                   = "My Store API"
  config.api_version             = "2.0.0"
  config.route_filter            = ->(route) { route.path.start_with?("/api/") }
  config.exclude_source_paths    = ["vendor/", %r{app/controllers/legacy/}]
  config.method_resolution_depth = 5
end
```

## 設定項目一覧

| 設定 | デフォルト | 説明 |
|---|---|---|
| `output_path` | `"doc/openapi.json"` | specファイルの出力先 |
| `format` | 拡張子から自動判定 | `:json` または `:yaml` |
| `title` | アプリ名 | specの`info.title` |
| `api_version` | `"1.0.0"` | specの`info.version` |
| `route_filter` | すべて含む | ルートごとに呼ばれるlambda — `false`を返すと除外 |
| `exclude_source_paths` | `[]` | コントローラのソースファイルパスに対してマッチする文字列または正規表現 |
| `method_resolution_depth` | `5` | ヘルパー・コールバックチェーンを追跡する深さ |

## output\_path と format

```ruby
config.output_path = "doc/openapi.json"   # JSON出力
config.output_path = "doc/openapi.yaml"   # YAML出力
config.output_path = "doc/openapi.yml"    # YAMLも可
```

フォーマットは拡張子から自動判定されます。`config.format`で明示的に指定することもできます。

```ruby
config.format = :yaml
```

## title と api\_version

OpenAPIの`info`オブジェクトに直接対応します。

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "My Store API",
    "version": "2.0.0"
  }
}
```

## route\_filter

ルートオブジェクトを受け取り、`true`で含める・`false`で除外するlambdaです。APIネームスペースに限定する場合などに便利です。

```ruby
# /api/ 以下のルートのみ含める
config.route_filter = ->(route) { route.path.start_with?("/api/") }

# 特定のパスを除外
config.route_filter = ->(route) { !route.path.start_with?("/internal/") }

# JSON対応のverbのみ
config.route_filter = ->(route) { %w[GET POST PUT PATCH DELETE].include?(route.verb) }
```

詳しくは[ルートフィルタリング](../guides/route-filtering.md)を参照してください。

## exclude\_source\_paths

コントローラのソースファイルパスに対してマッチする文字列または正規表現の配列です。少なくとも1つのエントリにマッチしたコントローラは除外されます。

```ruby
config.exclude_source_paths = [
  "vendor/",                            # vendor/ 以下のすべて
  %r{app/controllers/admin/},           # adminネームスペース
  "app/controllers/devise/",            # Deviseコントローラ
]
```

## method\_resolution\_depth

ヘルパーメソッドの呼び出しや`before_action`コールバック、`rescue_from`ハンドラを追跡する際に、何段階まで深く追うかを制御します。

```ruby
config.method_resolution_depth = 5   # デフォルト
```

深くネストされたヘルパーチェーンがある場合は増やしてください。大規模アプリで速度を優先する場合は減らすこともできます。

## コマンドラインでの一時的な上書き

```sh
rake openapi:generate OUTPUT=tmp/openapi.yaml FORMAT=yaml
```

`OUTPUT`と`FORMAT`は、その1回の実行のみイニシャライザの設定を上書きします。

## CLIの場合

```sh
bundle exec rails-openapi-generator \
  --rails-root . \
  --output doc/openapi.json
```
