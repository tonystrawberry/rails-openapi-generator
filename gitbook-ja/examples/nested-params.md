# サンプル: ネストされたパラメータ

このサンプルでは、深くネストされた`param!`ブロックで複雑なリクエストボディを文書化する方法を示します。設定オブジェクト、複数パートのフォーム、構造化データAPIなどでよく使われるパターンです。

## ユースケース: ランディングページ設定

ネストされた設定オブジェクトを受け付ける設定エンドポイント:

```ruby
# app/controllers/api/settings_controller.rb
class Api::SettingsController < ApplicationController
  # ランディングページ設定を更新
  def update
    param! :landing_page_setting, Hash, required: true do |h|
      h.param! :downloadable, :boolean, required: true,
               description: "コンテンツをデフォルトでダウンロード可能にするか"

      h.param! :background_color, String, required: false,
               format: /\A#[0-9a-fA-F]{6}\z/,
               description: "16進数カラーコード（例: #ffffff）"

      h.param! :sections, Hash, required: false do |s|
        s.param! :hero, Hash, required: false do |hero|
          hero.param! :title,    String,   required: true
          hero.param! :subtitle, String,   required: false
          hero.param! :visible,  :boolean, required: true
        end

        s.param! :logo, Hash, required: false do |logo|
          logo.param! :url,     String,   required: true
          logo.param! :alt,     String,   required: false, description: "アクセシビリティ用のaltテキスト"
          logo.param! :visible, :boolean, required: true
        end
      end
    end

    # ...
    head :ok
  end
end
```

## 生成されるrequestBodyスキーマ

```json
{
  "requestBody": {
    "required": true,
    "content": {
      "application/json": {
        "schema": {
          "type": "object",
          "required": ["landing_page_setting"],
          "properties": {
            "landing_page_setting": {
              "type": "object",
              "required": ["downloadable"],
              "properties": {
                "downloadable": {
                  "type": "boolean",
                  "description": "コンテンツをデフォルトでダウンロード可能にするか"
                },
                "background_color": {
                  "type": "string",
                  "pattern": "\\A#[0-9a-fA-F]{6}\\z",
                  "description": "16進数カラーコード（例: #ffffff）"
                },
                "sections": {
                  "type": "object",
                  "properties": {
                    "hero": {
                      "type": "object",
                      "required": ["title", "visible"],
                      "properties": {
                        "title":    { "type": "string" },
                        "subtitle": { "type": "string" },
                        "visible":  { "type": "boolean" }
                      }
                    },
                    "logo": {
                      "type": "object",
                      "required": ["url", "visible"],
                      "properties": {
                        "url":     { "type": "string" },
                        "alt":     { "type": "string", "description": "アクセシビリティ用のaltテキスト" },
                        "visible": { "type": "boolean" }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

## このサンプルで示されるポイント

### :boolean省略形

```ruby
h.param! :downloadable, :boolean, required: true
```

`:boolean`シンボル（`TrueClass`/`FalseClass`の代わり）は`"type": "boolean"`にマッピングされます。どちらの形式も機能します。

### 任意のネスト深度

`sections → hero`と`sections → logo`のパスは、トップレベルの`landing_page_setting`から3段階深くなっています。ネストの深さに設定上の制限はありません。

### 各レベルのrequired

各ネストレベルの`required: true`は、そのキーをルートのrequired配列ではなく、**親オブジェクト**の`required`配列に追加します。ジェネレーターはネストのコンテキストを正しく追跡します。

### descriptionの伝播

任意の深さの`param!`呼び出しに`description:`を付けると、そのプロパティに説明が付与されます。

## オブジェクトの配列

ボディパラメータが構造化オブジェクトの配列の場合、`Array`を型として使い、ネストされたブロックを記述します。

```ruby
param! :items, Array, required: true do |item|
  item.param! :product_id, Integer, required: true
  item.param! :quantity,   Integer, required: true, in: 1..999
  item.param! :note,       String,  required: false
end
```

→ `items`は`{ "type": "array", "items": { "type": "object", "required": ["product_id", "quantity"], "properties": { ... } } }`になります。

## ボディパラメータとパスパラメータの混在

パスセグメントは`param!`呼び出しに関わらず常にパスパラメータになります。ボディパラメータはPOST/PUT/PATCHの`param!`呼び出しです。

```ruby
# PUT /api/users/:id/settings
def update_settings
  # :idはルートから → 自動的にパスパラメータになる
  param! :theme, String, in: %w[light dark], description: "UIテーマの設定"
end
```

→ 1つのパスパラメータ（`id`）と1つのリクエストボディプロパティ（`theme`）。
