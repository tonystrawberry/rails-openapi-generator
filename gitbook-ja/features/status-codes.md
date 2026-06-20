# ステータスコード

ジェネレーターはコントローラアクション、および呼び出されるすべての`before_action`やヘルパーメソッド内の`head`、`render status:`、`redirect_to`の呼び出しからHTTPステータスコードを読み取ります。

## デフォルトの規約

明示的なステータスが設定されていない場合、HTTPメソッドの規約が適用されます。

| Verb | デフォルトステータス |
|---|---|
| GET | 200 |
| POST | 201 |
| PUT / PATCH | 200 |
| DELETE | 204（ボディなし） |

## renderへの明示的なステータス指定

```ruby
render json: { ok: true }, status: :created        # → 201
render json: { ok: true }, status: :ok             # → 200
render json: { errors: [...] }, status: 422        # → 422
render json: { errors: [...] }, status: :unprocessable_entity  # → 422
```

シンボル形式と整数形式の両方が認識されます。

## head（ボディなし）

```ruby
head :no_content      # → 204、レスポンスボディエントリなし
head :ok              # → 200、レスポンスボディエントリなし
head :unauthorized    # → 401、レスポンスボディエントリなし
```

## リダイレクト

```ruby
redirect_to root_path                          # → 302
redirect_to root_path, status: :see_other      # → 303
redirect_to root_path, status: :moved_permanently  # → 301
```

リダイレクトレスポンスはボディスキーマなしのレスポンスエントリを生成します。

## 1つのアクションから複数のステータスコード

アクションに条件付きレンダーパスがある場合、到達可能なすべてのステータスコードがspecに含まれます。

```ruby
def show
  @user = User.find_by(id: params[:id])
  if @user
    render json: @user                          # 200
  else
    render json: { error: "not found" }, status: :not_found   # 404
  end
end
```

→ オペレーションに`200`と`404`の両方のレスポンスエントリが含まれます。

ジェネレーターは到達可能性を証明しようとはしません。アクションボディ、ヘルパーチェーン、適用される`before_action`コールバックで見えるすべての`render`/`head`/`redirect_to`を収集します。見えるレンダーサイトはすべて到達可能であるという保守的な前提を取ります。

## before\_actionからのステータスコード

```ruby
before_action :require_authentication

def require_authentication
  head :unauthorized unless current_user
end
```

`require_authentication`が適用されるすべてのアクションのレスポンスリストに`401`エントリ（ボディなし）が追加されます。

## rescue\_fromからのステータスコード

[エラーレスポンス](error-responses.md)を参照してください。`rescue_from`ハンドラは、コントローラ階層内のすべてのオペレーションにステータスコードとスキーマを付与します。
