# Example: Basic CRUD API

This example walks through a complete users CRUD API — routes, controller, views, and the resulting OpenAPI spec entries.

## Routes

```ruby
# config/routes.rb
namespace :api do
  resources :users, only: [:index, :show, :create, :update, :destroy]
end
```

This produces:

```
GET    /api/users
POST   /api/users
GET    /api/users/:id
PUT    /api/users/:id
PATCH  /api/users/:id
DELETE /api/users/:id
```

## Controller

```ruby
# app/controllers/api/users_controller.rb
class Api::UsersController < ApplicationController
  # List users
  # Returns all active users ordered by signup date, newest first.
  def index
    param! :page,     Integer, default: 1,  description: "Page number"
    param! :per_page, Integer, in: 1..100,  default: 25, description: "Results per page"
    param! :status,   String,  in: %w[active archived], description: "Filter by status"

    @users = User.active.order(created_at: :desc).page(params[:page]).per(params[:per_page])
    render :index
  end

  # Get a user
  # Returns the user with the given ID.
  def show
    @user = User.find(params[:id])
    render :show
  end

  # Create a user
  def create
    param! :name,  String, required: true, description: "Display name"
    param! :email, String, required: true, format: /.+@.+/, description: "Email address"
    param! :role,  String, in: %w[admin member], description: "User role"

    @user = User.create!(user_params)
    render :show, status: :created
  end

  # Update a user
  def update
    param! :name,  String, description: "Display name"
    param! :email, String, format: /.+@.+/, description: "Email address"
    param! :role,  String, in: %w[admin member]

    @user = User.find(params[:id])
    @user.update!(user_params)
    render :show
  end

  # Delete a user
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

## Views

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

## Error handler (ApplicationController)

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

## Generated spec (summary)

After running `rake openapi:generate`, the document includes:

### GET /api/users

```yaml
summary: List users
description: Returns all active users ordered by signup date, newest first.
parameters:
  - name: page
    in: query
    description: Page number
    schema: { type: integer, default: 1 }
  - name: per_page
    in: query
    description: Results per page
    schema: { type: integer, minimum: 1, maximum: 100, default: 25 }
  - name: status
    in: query
    description: Filter by status
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
  "404":
    content:
      application/json:
        schema:
          type: object
          properties:
            error:
              type: object
              properties:
                code:    { type: string, example: NOT_FOUND }
                message: { type: string, example: Record not found }
  "422": # ... (from RecordInvalid rescue_from)
```

### POST /api/users

```yaml
summary: Create a user
requestBody:
  required: true
  content:
    application/json:
      schema:
        type: object
        required: [name, email]
        properties:
          name:  { type: string, description: Display name }
          email: { type: string, pattern: ".+@.+", description: Email address }
          role:  { type: string, enum: [admin, member], description: User role }
responses:
  "201":
    content:
      application/json:
        schema: { /* user partial schema */ }
  "404": { /* from rescue_from */ }
  "422": { /* from rescue_from */ }
```

### DELETE /api/users/:id

```yaml
summary: Delete a user
parameters:
  - name: id
    in: path
    required: true
    schema: {}
responses:
  "204":
    description: "204"
  "404": { /* from rescue_from */ }
```

## Adding a sidecar to improve the user schema

The `_user` partial uses `extract!`-style calls on model attributes, so the properties are typed as `{}` (unknown). To get precise types, add:

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

Now every endpoint that renders the `_user` partial — `index`, `show`, `create`, `update` — inherits this precise schema automatically.
