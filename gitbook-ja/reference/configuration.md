# 設定オプション

`RailsOpenapiGenerator.configure`が受け付けるすべての設定の完全リファレンスです。

## output\_path

**型:** `String`
**デフォルト:** `"doc/openapi.json"`

specファイルの書き出し先パス（Railsルートからの相対パス）。

```ruby
config.output_path = "doc/openapi.json"    # JSON
config.output_path = "doc/openapi.yaml"    # YAML
config.output_path = "public/api-spec.yml" # YAMLも可
```

フォーマット（JSON vs YAML）は拡張子から自動判定されます（`.json` → JSON、`.yaml` / `.yml` → YAML）。上書きするには`format`を参照してください。

---

## format

**型:** `:json` または `:yaml`
**デフォルト:** `output_path`の拡張子から自動判定

```ruby
config.format = :yaml
```

`output_path`の拡張子が希望するフォーマットと一致しない場合のみ明示的に設定してください。

---

## title

**型:** `String`
**デフォルト:** `Rails.application.class.module_parent_name`

生成されたドキュメントの`info.title`を設定します。

```ruby
config.title = "My Store API"
```

---

## api\_version

**型:** `String`
**デフォルト:** `"1.0.0"`

生成されたドキュメントの`info.version`を設定します。任意の文字列が有効です。

```ruby
config.api_version = "2.0.0"
config.api_version = "v2024-01"
```

---

## route\_filter

**型:** `Proc`（lambda）
**デフォルト:** `nil`（すべてのルートを含む）

各ルートオブジェクトで呼ばれるlambda。`true`で含める、`false`で除外します。

```ruby
config.route_filter = ->(route) { route.path.start_with?("/api/") }
```

ルートオブジェクトが公開する属性:

| 属性 | 例 |
|---|---|
| `route.path` | `"/api/users/:id"` |
| `route.verb` | `"GET"` |
| `route.controller` | `"api/users"` |
| `route.action` | `"show"` |

詳しくは[ルートフィルタリング](../guides/route-filtering.md)を参照してください。

---

## exclude\_source\_paths

**型:** `Array<String | Regexp>`
**デフォルト:** `[]`

コントローラのソースファイルパスにマッチする文字列または正規表現の配列。少なくとも1つのエントリにマッチするルートのコントローラは除外されます。

```ruby
config.exclude_source_paths = [
  "vendor/",
  "app/controllers/devise/",
  %r{app/controllers/admin/},
]
```

- **文字列** — 部分文字列マッチ
- **正規表現** — `=~`でマッチ

---

## method\_resolution\_depth

**型:** `Integer`
**デフォルト:** `5`

ヘルパーチェーン、`before_action`コールバック、`rescue_from`ハンドラを追跡する際にメソッド呼び出しを何段階まで追うかを制御します。

```ruby
config.method_resolution_depth = 5   # デフォルト
config.method_resolution_depth = 10  # 深くネストされたヘルパーの場合
config.method_resolution_depth = 2   # 大規模アプリの速度優先
```

増やすと、深くネストされたヘルパー階層に埋もれた`render`/`head`/`send_file`呼び出しを見つけられます。減らすと、いくつかのレスポンスサイトを見逃す代わりに生成が速くなります。

---

## 環境変数（一時的な上書き）

イニシャライザを変更せずに、1回のrake実行のみ設定値を上書きします。

```sh
rake openapi:generate OUTPUT=tmp/openapi.yaml FORMAT=yaml
```

| 変数 | 上書き対象 |
|---|---|
| `OUTPUT` | `output_path` |
| `FORMAT` | `format` |

---

## CLIフラグ

```sh
bundle exec rails-openapi-generator \
  --rails-root /path/to/app \
  --output doc/openapi.json
```

| フラグ | 説明 |
|---|---|
| `--rails-root PATH` | Railsアプリケーションのルートパス |
| `--output PATH` | 出力ファイルパス（`config.output_path`を上書き） |
