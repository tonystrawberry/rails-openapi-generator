# パラメータ

ジェネレーターはコントローラアクション内の`param!`呼び出し（`rails_param` DSL）からパラメータを抽出します。GET/DELETEルートではクエリパラメータ、POST/PUT/PATCHルートではリクエストボディパラメータが生成されます。

## クエリパラメータ

```ruby
def index
  param! :query,    String,  blank: false, description: "フリーテキスト検索"
  param! :page,     Integer, default: 1
  param! :per_page, Integer, in: 1..100, default: 25
  param! :status,   String,  in: %w[active archived]
end
```

`GET /users`に3つのクエリパラメータが生成されます。

```json
{
  "parameters": [
    {
      "name": "query",
      "in": "query",
      "description": "フリーテキスト検索",
      "schema": { "type": "string" }
    },
    {
      "name": "page",
      "in": "query",
      "schema": { "type": "integer", "default": 1 }
    },
    {
      "name": "per_page",
      "in": "query",
      "schema": { "type": "integer", "minimum": 1, "maximum": 100, "default": 25 }
    },
    {
      "name": "status",
      "in": "query",
      "schema": { "type": "string", "enum": ["active", "archived"] }
    }
  ]
}
```

## パスパラメータ

ルートで定義されたパスセグメント（例: `:id`、`:user_id`）は自動的にパスパラメータになります。`param!`呼び出しは不要です。

```ruby
# routes.rb
resources :users
# → GET /users/:id は自動的に { "name": "id", "in": "path", "required": true } を持つ
```

説明や型制約を追加したい場合は、対応する`param!`を追加します。

```ruby
def show
  param! :id, Integer, required: true, description: "ユーザーの主キー"
end
```

## リクエストボディ（POST / PUT / PATCH）

変更系のverbでは、トップレベルの`param!`呼び出しがクエリパラメータではなく`requestBody`のプロパティになります。

```ruby
def create
  param! :name,  String, required: true, description: "表示名"
  param! :email, String, required: true, format: /.+@.+/
  param! :role,  String, in: %w[admin member]
end
```

生成結果:

```json
{
  "requestBody": {
    "required": true,
    "content": {
      "application/json": {
        "schema": {
          "type": "object",
          "required": ["name", "email"],
          "properties": {
            "name":  { "type": "string", "description": "表示名" },
            "email": { "type": "string", "pattern": ".+@.+" },
            "role":  { "type": "string", "enum": ["admin", "member"] }
          }
        }
      }
    }
  }
}
```

## ネストされたパラメータ

`Hash`とブロックを使ってネストされたオブジェクトを記述できます。

```ruby
param! :address, Hash, required: true do |a|
  a.param! :street, String, required: true
  a.param! :city,   String, required: true
  a.param! :zip,    String, required: true, format: /\A\d{5}\z/
end
```

ネストの深さに制限はありません。

```ruby
param! :landing_page_setting, Hash, required: true do |h|
  h.param! :downloadable, :boolean, required: true, description: "デフォルトのダウンロード可否フラグ"
  h.param! :sections, Hash, required: false do |s|
    s.param! :logo, Hash, required: false do |logo|
      logo.param! :visible, :boolean, required: true
    end
  end
end
```

## 型のマッピング

| `param!`の型 | OpenAPIの`type` |
|---|---|
| `String` | `string` |
| `Integer` | `integer` |
| `Float` | `number` |
| `Hash` | `object` |
| `Array` | `array` |
| `:boolean` | `boolean` |
| `TrueClass` / `FalseClass` | `boolean` |

## 制約のマッピング

| `param!`の制約 | OpenAPIキーワード |
|---|---|
| `in: %w[a b c]` | `enum` |
| `in: 1..100` | `minimum` / `maximum` |
| `format: /regex/` | `pattern` |
| `required: true` | `required`配列に追加 |
| `default: value` | `default` |
| `blank: false` | `minLength: 1`（文字列の場合） |

## `description`オプション

任意の`param!`呼び出しに`description:`を渡すと、パラメータレベルの説明が付与されます。

```ruby
param! :sort, String, in: %w[asc desc], description: "ソート方向"
```

→ `"description": "ソート方向"`がパラメータに付与されます。
