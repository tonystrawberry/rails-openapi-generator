# クイックスタート

このページでは、Gemのインストールから動作するOpenAPIドキュメントの生成まで、5分以内で完了する手順を説明します。

## 1. Gemをインストール

```ruby
# Gemfile
gem "rails-openapi-generator"
```

```sh
bundle install
```

## 2. ジェネレーターを実行

```sh
bundle exec rake openapi:generate
```

ジェネレーターはサマリーを表示してspecファイルを書き出します。

```
OpenAPI document written to doc/openapi.json
  Processed: 42 endpoints
  Skipped:   1
    - GET /legacy (no backing controller action)
  Warnings:  0
```

出力ファイルはデフォルトで`doc/openapi.json`です。再実行するとバイト単位で同一な出力が得られるため、コミットしてCIでdiffするのに適しています。

## 3. specをプレビュー

Redocで開く（インストール不要）:

```sh
npx @redocly/cli build-docs doc/openapi.json -o doc/openapi.html
open doc/openapi.html
```

またはSwagger UIをDockerで起動:

```sh
docker run --rm -p 8081:8080 \
  -e SWAGGER_JSON=/spec/openapi.json \
  -v "$PWD/doc:/spec" swaggerapi/swagger-ui
```

`http://localhost:8081`にアクセスします。

## 4. 最初のエンドポイントをドキュメント化

コントローラアクションにYARDコメントと`param!`呼び出しを追加します。

```ruby
class Api::UsersController < ApplicationController
  # ユーザー一覧
  # 作成日時の降順で全アクティブユーザーを返します。
  def index
    param! :page,     Integer, default: 1
    param! :per_page, Integer, in: 1..100, default: 25
    # ...
  end
end
```

`rake openapi:generate`を再実行すると、`GET /api/users`オペレーションにサマリー、説明、および2つのクエリパラメータとその制約が追加されます。

## 5. specをバージョン管理にコミット

```sh
git add doc/openapi.json
git commit -m "Add generated OpenAPI spec"
```

CIパイプラインに生成ステップを追加して、ドリフトを検知します。

```yaml
# .github/workflows/ci.yml（例）
- run: bundle exec rake openapi:generate
- run: git diff --exit-code doc/openapi.json
```

## 次のステップ

[設定 →](configuration.md)
