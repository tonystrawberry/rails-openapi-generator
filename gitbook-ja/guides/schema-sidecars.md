# JSONスキーマサイドカー

JSONスキーマサイドカーとは、ビューの隣またはアクションのビューパスに配置する`.schema.json`ファイルです。存在する場合、ジェネレーターの推論スキーマを明示的に記述したものに置き換えます。

サイドカーは静的推論が届かないケース — 条件付きフィールド、ポリモーフィック型、深く型付けされた`extract!`呼び出し、または完全に自分で管理したいスキーマ — のためのエスケープハッチです。

## 配置場所

| ファイルの場所 | 適用タイミング |
|---|---|
| `app/views/api/users/show.schema.json` | `UsersController#show`のレスポンス |
| `app/views/api/users/create.schema.json` | `UsersController#create`のレスポンス |
| `app/views/api/users/_user.schema.json` | `_user`パーシャルが解決される場所すべて |

命名規則はビューファイルと同じで、同じディレクトリ、同じベース名、拡張子が`.schema.json`です。パーシャルの場合はベース名の前にアンダースコアを付けます。

## 基本的な例

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["id", "email"],
  "properties": {
    "id":    { "type": "integer", "minimum": 1, "example": 42 },
    "email": { "type": "string",  "format": "email", "example": "alice@example.com" },
    "role":  { "type": "string",  "enum": ["admin", "member"] },
    "name":  { "type": "string",  "example": "Alice" }
  }
}
```

このファイルを`app/views/api/users/show.schema.json`に配置すると、ジェネレーターは`UsersController#show`の200レスポンスにこれをそのまま使用し、`show.json.jbuilder`を完全に無視します。

## $defsを使った共有型

`$defs`で再利用可能なサブスキーマを定義し、`$ref`で参照できます。

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$defs": {
    "Address": {
      "type": "object",
      "required": ["street", "city"],
      "properties": {
        "street": { "type": "string" },
        "city":   { "type": "string" },
        "zip":    { "type": "string", "pattern": "^\\d{5}$" }
      }
    }
  },
  "type": "object",
  "properties": {
    "id":      { "type": "integer" },
    "billing": { "$ref": "#/$defs/Address" },
    "shipping":{ "$ref": "#/$defs/Address" }
  }
}
```

ジェネレーターは`$defs`をトップレベルのOpenAPI `components/schemas`セクションにホイストし、`$ref`パスを書き換えます。サイドカーファイル内で`#/$defs/Address`だったものが、最終specでは`#/components/schemas/Address`になります。

### ファイルをまたいだ$ref

別のサイドカーファイルの定義を参照できます。

```json
{
  "type": "object",
  "properties": {
    "user":    { "$ref": "app/views/api/users/_user.schema.json#/$defs/UserSummary" },
    "comment": { "$ref": "app/views/api/comments/_comment.schema.json" }
  }
}
```

ジェネレーターはRailsルートからの相対パスを解決します。参照先のファイルがロードされ、その`$defs`がホイストされ、`$ref`値はホイストされたコンポーネントを指すように書き換えられます。

## ビューファイルなしのサイドカー

サイドカーは対応する`.json.jbuilder`テンプレートがない場合でも存在できます。インラインJSONをレンダーするアクションや、特定のアクションだけ継承したパーシャルのスキーマをオーバーライドしたい場合に便利です。

```
app/views/api/users/bulk_create.schema.json   ← bulk_create.json.jbuilder は不要
```

## エラー処理

サイドカーファイルに不正なJSONが含まれている場合:

- ジェネレーターは生成レポートに警告を出力します
- そのアクションの推論スキーマにフォールバックします
- 生成は継続されます — 例外は発生しません

```
Warnings:
  - app/views/api/users/show.schema.json: invalid JSON — falling back to inferred schema
```

## サイドカーを使うタイミング vs テンプレートの改善

サイドカーを使う場合:

- jbuilderテンプレートが`extract!`を使っていて、個々のプロパティに正確な型が必要な場合
- レスポンススキーマが条件付きまたはポリモーフィックな場合（例: `type`フィールドに基づく2つの形状の`oneOf`）
- `format`、`minimum`、`maximum`、`pattern`などjbuilderが表現できない制約を追加したい場合
- jbuilderテンプレートが存在しない場合（インラインJSONレンダーまたは外部ソース）

推論に任せる場合:

- テンプレートがシンプルで、リテラルがすでに良い`example`値を提供している場合
- 並行してスキーマファイルを管理したくない場合

## サイドカーの検証

コミット前にJSONスキーマバリデーターでサイドカーを確認できます。

```sh
npx ajv validate -s https://json-schema.org/draft/2020-12/schema -d app/views/**/*.schema.json
```
