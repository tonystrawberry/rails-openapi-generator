# サンプル: 基本的なCRUD API

このサンプルでは、ユーザーのCRUD APIを完全に実装します。ルート、コントローラ、ビュー、そして生成されるOpenAPIのspecエントリを順に説明します。

## ルート

```ruby
# config/routes.rb
namespace :api do
  resources :users, only: [:index, :show, :create, :update, :destroy]
end
```

以下のルートが生成されます。

```
GET    /api/users
POST   /api/users
GET    /api/users/:id
PUT    /api/users/:id
PATCH  /api/users/:id
DELETE /api/users/:id
```

## コントローラ

```ruby
# app/controllers/api/users_controller.rb
class Api::UsersController < ApplicationController
  # ユーザー一覧
  # サインアップ日時の降順で全アクティブユーザーを返します。
  def index
    param! :page,     Integer, default: 1,  description: "ページ番号"
    param! :per_page, Integer, in: 1..100,  default: 25, description: "1ページあたりの件数"
    param! :status,   String,  in: %w[active archived], description: "ステータスでフィルタ"

    @users = User.active.order(created_at: :desc).page(params[:page]).per(params[:per_page])
    render :index
  end

  # ユーザーを取得
  # 指定されたIDのユーザーを返します。
  def show
    @user = User.find(params[:id])
    render :show
  end

  # ユーザーを作成
  def create
    param! :name,  String, required: true, description: "表示名"
    param! :email, String, required: true, format: /.+@.+/, description: "メールアドレス"
    param! :role,  String, in: %w[admin member], description: "ユーザーロール"

    @user = User.create!(user_params)
    render :show, status: :created
  end

  # ユーザーを更新
  def update
    param! :name,  String, description: "表示名"
    param! :email, String, format: /.+@.+/, description: "メールアドレス"
    param! :role,  String, in: %w[admin member]

    @user = User.find(params[:id])
    @user.update!(user_params)
    render :show
  end

  # ユーザーを削除
  def destroy
    User.find(params[:id]).destroy!
    head :no_content
  end

  private

  def user_params
    params.permit(:name, :email, :role)
  end
end
```

## ビュー

```ruby
# app/views/api/users/_user.json.jbuilder
json.id         user.id
json.name       user.name
json.email      user.email
json.role       user.role
json.created_at user.created_at.iso8601
```

```ruby
# app/views/api/users/index.json.jbuilder
json.users @users, partial: "user", as: :user
json.meta do
  json.page     @users.current_page
  json.per_page @users.limit_value
  json.total    @users.total_count
end
```

```ruby
# app/views/api/users/show.json.jbuilder
json.partial! "user", user: @user
```

## エラーハンドラ（ApplicationController）

```ruby
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: { code: "NOT_FOUND", message: "Record not found" } },
           status: :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: { code: "INVALID", message: e.message } },
           status: :unprocessable_entity
  end
end
```

## 生成されるspec（サマリー）

`rake openapi:generate`を実行すると、ドキュメントに以下が含まれます。

### GET /api/users

```yaml
summary: ユーザー一覧
description: サインアップ日時の降順で全アクティブユーザーを返します。
parameters:
  - name: page
    in: query
    description: ページ番号
    schema: { type: integer, default: 1 }
  - name: per_page
    in: query
    description: 1ページあたりの件数
    schema: { type: integer, minimum: 1, maximum: 100, default: 25 }
  - name: status
    in: query
    description: ステータスでフィルタ
    schema: { type: string, enum: [active, archived] }
responses:
  "200":
    content:
      application/json:
        schema:
          type: object
          properties:
            users:
              type: array
              items:
                type: object
                properties:
                  id:         {}
                  name:       {}
                  email:      {}
                  role:       {}
                  created_at: {}
            meta:
              type: object
              properties:
                page:     {}
                per_page: {}
                total:    {}
  "404":   # rescue_fromから
  "422":   # rescue_fromから
```

### POST /api/users

```yaml
summary: ユーザーを作成
requestBody:
  required: true
  content:
    application/json:
      schema:
        type: object
        required: [name, email]
        properties:
          name:  { type: string, description: 表示名 }
          email: { type: string, pattern: ".+@.+", description: メールアドレス }
          role:  { type: string, enum: [admin, member], description: ユーザーロール }
responses:
  "201":
    content:
      application/json:
        schema: { /* ユーザーパーシャルのスキーマ */ }
  "404": { /* rescue_fromから */ }
  "422": { /* rescue_fromから */ }
```

### DELETE /api/users/:id

```yaml
summary: ユーザーを削除
parameters:
  - name: id
    in: path
    required: true
    schema: {}
responses:
  "204":
    description: "204"
  "404": { /* rescue_fromから */ }
```

## サイドカーでユーザースキーマを改善する

`_user`パーシャルはモデル属性へのメソッド呼び出しを使っているため、プロパティは`{}`（不明）型になります。正確な型を付与するには:

```json
// app/views/api/users/_user.schema.json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["id", "name", "email"],
  "properties": {
    "id":         { "type": "integer",  "example": 1 },
    "name":       { "type": "string",   "example": "Alice" },
    "email":      { "type": "string",   "format": "email", "example": "alice@example.com" },
    "role":       { "type": "string",   "enum": ["admin", "member"] },
    "created_at": { "type": "string",   "format": "date-time" }
  }
}
```

`_user`パーシャルをレンダーするすべてのエンドポイント（`index`、`show`、`create`、`update`）が自動的にこの正確なスキーマを継承します。
