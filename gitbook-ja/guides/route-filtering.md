# ルートフィルタリング

デフォルトでは、ジェネレーターはRailsアプリケーションのすべてのルートを処理します。`route_filter`と`exclude_source_paths`を使って出力を絞り込めます。

## route\_filter

ルートごとに一度呼ばれるlambdaです。`false`を返すとそのルートがspecから除外されます。

```ruby
RailsOpenapiGenerator.configure do |config|
  config.route_filter = ->(route) { route.path.start_with?("/api/") }
end
```

### ルートオブジェクト

lambdaは以下の属性を持つオブジェクトを受け取ります。

| 属性 | 型 | 例 |
|---|---|---|
| `route.path` | String | `"/api/users/:id"` |
| `route.verb` | String | `"GET"` |
| `route.controller` | String | `"api/users"` |
| `route.action` | String | `"show"` |

### よくあるパターン

```ruby
# /api/ ネームスペースのみ含める
config.route_filter = ->(r) { r.path.start_with?("/api/") }

# ヘルスチェックと内部ルートを除外
config.route_filter = ->(r) {
  !r.path.start_with?("/health", "/internal/", "/sidekiq")
}

# 特定のverbのみ含める
config.route_filter = ->(r) { %w[GET POST PUT PATCH DELETE].include?(r.verb) }

# コントローラのないルートを除外（マウントされたエンジンなど）
config.route_filter = ->(r) { r.controller.present? }

# 組み合わせ: /api/ ルートのみ、ただしWebhookは除外
config.route_filter = ->(r) {
  r.path.start_with?("/api/") && !r.path.include?("/webhooks/")
}
```

## exclude\_source\_paths

コントローラのソース**ファイルパス**にマッチする文字列または正規表現の配列です。少なくとも1つのエントリにマッチするコントローラは除外され、そのすべてのルートがスキップされます。

```ruby
RailsOpenapiGenerator.configure do |config|
  config.exclude_source_paths = [
    "vendor/",                          # サードパーティエンジン
    "app/controllers/devise/",          # Deviseが生成したコントローラ
    %r{app/controllers/admin/},         # 正規表現: adminネームスペース
    %r{/legacy/},                       # 正規表現: legacy/ 以下のすべて
  ]
end
```

### 文字列 vs 正規表現

- **文字列** — ファイルパス全体に対する部分文字列マッチ
- **正規表現** — ファイルパス全体に対して`=~`でマッチ

```ruby
# 文字列: "vendor/"を含む任意のパスにマッチ
"vendor/"

# 正規表現: app/controllers/v1/admin/users_controller.rb などにマッチ
%r{/admin/}
```

## 両方のフィルターを組み合わせる

`route_filter`と`exclude_source_paths`は一緒に適用されます。ルートが含まれるには両方を通過する必要があります。パスベースのルールには`route_filter`を、ファイルベースのルールには`exclude_source_paths`を使います。

```ruby
RailsOpenapiGenerator.configure do |config|
  # APIパスのみ
  config.route_filter = ->(r) { r.path.start_with?("/api/") }
  # ただし、パスに関わらずDeviseとlegacyコントローラは除外
  config.exclude_source_paths = ["app/controllers/devise/", %r{/legacy/}]
end
```

## コマンドラインでの一時的なフィルター

```sh
rake openapi:generate OUTPUT=tmp/users-only.json FILTER=/api/users
```

`FILTER`はパスプレフィックスで、その1回の実行のみ`route_filter`を上書きします。

## 生成対象の確認

CLIの`--dry-run`オプションを使うと、ファイルを書き出さずにどのルートが含まれるかを確認できます。

```sh
bundle exec rails-openapi-generator --rails-root . --dry-run
```

通常の実行後に生成レポートを確認することでも、スキップされたルートとその理由を一覧できます。
