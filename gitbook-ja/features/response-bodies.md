# レスポンスボディ

ジェネレーターは優先順位に従って4つのソースからレスポンススキーマを導出します。アプリ内の異なるアクションでソースを混在させることもできます。

## ソース1: jbuilderテンプレート

JSONレスポンスの主要なソースです。ジェネレーターはRubyの`Ripper` ASTパーサーを使って`.json.jbuilder`ファイルを静的に解析します。コードは実行されません。

```ruby
# app/views/api/users/show.json.jbuilder
json.id         user.id
json.name       user.name
json.email      user.email
json.role       "member"           # リテラル → example値を持つ
json.active     true               # リテラル → example値を持つ
json.created_at user.created_at
```

→ 6つのプロパティを持つオブジェクトスキーマ。リテラルは`example`値を生成し、モデルオブジェクトのメソッド呼び出しは`{}`（戻り値の型がパース時に不明なため）を生成します。

### ネストされたオブジェクト

```ruby
json.profile do
  json.bio      user.bio
  json.avatar   user.avatar_url
end
```

→ `{ "profile": { "type": "object", "properties": { "bio": {}, "avatar": {} } } }`

### `json.array!`による配列

```ruby
json.array! @users do |user|
  json.id   user.id
  json.name user.name
end
```

→ `{ "type": "array", "items": { "type": "object", "properties": { "id": {}, "name": {} } } }`

### `json.extract!`

```ruby
json.extract! user, :id, :name, :email
```

→ 3つのプロパティ、それぞれ`{}`型（不明 — サイドカーで型を追加できます）。

### パーシャル

```ruby
# app/views/api/users/index.json.jbuilder
json.users @users, partial: "user", as: :user
```

ジェネレーターはRailsの相対パーシャル規約を使ってパーシャル参照を辿り、パーシャルのスキーマを配列のアイテムスキーマとしてマージします。

```json
{
  "users": {
    "type": "array",
    "items": { /* _user.json.jbuilderのスキーマ */ }
  }
}
```

## ソース2: インラインの`render json:`

アクションがリテラルハッシュをレンダリングする場合、ハッシュ構造がスキーマになり、各値が`example`になります。

```ruby
render json: { id: 1, role: "member", active: true }, status: :created
```

→ 201レスポンス:

```json
{
  "type": "object",
  "properties": {
    "id":     { "type": "integer", "example": 1 },
    "role":   { "type": "string",  "example": "member" },
    "active": { "type": "boolean", "example": true }
  }
}
```

## ソース3: パーシャルの再帰的解析

テンプレートから参照されるパーシャルは推移的に解決されます。パーシャル自身が別のパーシャルを参照することもできます。循環参照は検出されて停止します。

## ソース4: JSONスキーマサイドカー

ビューの隣またはアクションのビューパスに`.schema.json`ファイルを配置すると、ジェネレーターの推論スキーマをあなたが明示的に記述したものに置き換えられます。サイドカーファイルはそのままロードされ、パーサーによって変更・マージされることはありません。

```
app/views/api/users/_user.schema.json       ← _userパーシャルが解決される場所で使用
app/views/api/users/show.schema.json        ← UsersController#showのレスポンスに使用
app/views/api/users/create.schema.json      ← .jbuilderファイルがなくても使用可能
```

詳しくは[JSONスキーマサイドカー](../guides/schema-sidecars.md)を参照してください。

## マルチステータスレスポンス

アクションに複数のレンダーパスがある場合、各ステータスコードに対応するレスポンスエントリが生成されます。

```ruby
def update
  if @user.update(user_params)
    render json: @user, status: :ok
  else
    render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
  end
end
```

→ 2つのエントリ: `200`（ユーザースキーマ）と`422`（エラースキーマ）。

同じステータスコードに異なるスキーマが2つある場合（例: 2つの異なるエラー形式がどちらも422を返す）、スキーマはOpenAPIの`oneOf`でユニオンされます。

## ビューファイルなし → 空スキーマ

アクションにjbuilderテンプレート、インラインrenderリテラル、サイドカーのいずれも存在しない場合、ジェネレーターは空スキーマ（`{}`）でレスポンスエントリを出力します。後からサイドカーを追加して補完できます。
