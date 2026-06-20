# エラーレスポンス

ジェネレーターは`rescue_from`宣言とハンドラ内のrender呼び出しを自動的に検出し、それらのレスポンスエントリをコントローラ階層内のすべてのオペレーションに追加します。

## 基本的な例

```ruby
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found
    render json: { error: { code: "NOT_FOUND", message: "Record not found" } },
           status: :not_found
  end
end
```

`ApplicationController`を継承するすべてのアクションに、そのボディスキーマを持つ`404`エントリが追加されます。個々のアクションに何も追加する必要はありません。

## 複数の rescue\_from ハンドラ

```ruby
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound,    with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid,     with: :render_unprocessable
  rescue_from Pundit::NotAuthorizedError,      with: :render_forbidden

  private

  def render_not_found
    render json: { error: { code: "NOT_FOUND" } }, status: :not_found
  end

  def render_unprocessable
    render json: { error: { code: "INVALID", details: [] } }, status: :unprocessable_entity
  end

  def render_forbidden
    render json: { error: { code: "FORBIDDEN" } }, status: :forbidden
  end
end
```

→ 継承するすべてのアクションに404、422、403のエントリが追加されます。

## ヘルパーへの引数の伝播

ハンドラがリテラル引数を持つヘルパーメソッドに委譲する場合、ジェネレーターは引数の値をコールチェーン全体に追跡します。

```ruby
rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

def render_forbidden
  render_error(status: :forbidden, code: "FORBIDDEN", message: "Access denied")
end

def render_error(status:, code:, message:)
  render json: { error: { code: code, message: message } }, status: status
end
```

ジェネレーターは呼び出しサイトから`status: :forbidden`、`code: "FORBIDDEN"`、`message: "Access denied"`を`render_error`のパラメータにバインドし、2段階深い`render`呼び出しを解決します。生成されるレスポンスエントリ:

```json
{
  "403": {
    "description": "403",
    "content": {
      "application/json": {
        "schema": {
          "type": "object",
          "properties": {
            "error": {
              "type": "object",
              "properties": {
                "code":    { "type": "string", "example": "FORBIDDEN" },
                "message": { "type": "string", "example": "Access denied" }
              }
            }
          }
        }
      }
    }
  }
}
```

## コンサーン

コントローラコンサーン内の`rescue_from`宣言は、コンサーンがコントローラチェーンにインクルードされている場合に検出されます。ジェネレーターはRubyと同じ方法で祖先リストを辿ります。

## スコープ付きrescue\_from（コントローラ単位）

ベース以外のコントローラで定義された`rescue_from`は、そのコントローラとそのサブクラスのアクションにのみ適用されます。

```ruby
class Api::PaymentsController < ApplicationController
  rescue_from Stripe::CardError, with: :render_card_error

  def render_card_error(e)
    render json: { error: { code: "CARD_ERROR", detail: e.message } }, status: :payment_required
  end
end
```

→ `Api::PaymentsController`のアクションのみに`402`エントリが追加されます。

## 重複排除

アクション自身のレンダーサイトと`rescue_from`ハンドラが同じステータスコードと同じスキーマを生成する場合、エントリは1つだけ出力されます。同一ステータスコード下の同一スキーマは常に重複排除されます。
