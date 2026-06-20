# インストール

## 動作要件

- Ruby 3.0以上
- Rails 7.0以上
- [`rails_param`](https://github.com/nicolasblanco/rails_param) Gem（任意 — `param!`でパラメータを文書化する場合のみ必要）

## Gemfileに追加

```ruby
# Gemfile
gem "rails-openapi-generator"
```

インストール:

```sh
bundle install
```

GemはRailtieを自動登録します。コード内に`require`文を記述する必要はありません。

## rakeタスクの確認

```sh
bundle exec rake -T openapi
# rake openapi:generate  # Generate OpenAPI 3.1 spec
```

タスクが表示されない場合は、`railties`がGemをロードしているか確認してください。エンジンや非標準の構成では、タスク登録が実行される前に`require "rails_openapi_generator"`を明示的に呼び出す必要がある場合があります。

## JSONまたはYAML出力

出力フォーマットは`output_path`に設定したファイルの拡張子から自動判定されます。デフォルトはJSONです。どちらのフォーマットも追加のGemは不要で、RailsがstdlibとしてJSONとYAMLの両方を含んでいます。

## 次のステップ

[クイックスタート →](quick-start.md)
