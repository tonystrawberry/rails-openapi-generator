# rails-openapi-generator

Railsアプリケーションの完全なOpenAPI 3.1ドキュメントを、**静的ソース解析**によって生成します。コントローラのコードは一切実行されず、テストサーバーも起動しません。

Gemはルートセット、コントローラ、jbuilderテンプレートをRubyの`Ripper` ASTパーサーで読み取り、毎回バイト単位で同一なspecファイルを出力します。

## 生成されるもの

デフォルトでは`doc/openapi.json`という単一のJSONまたはYAMLファイルが生成されます。すべてのルートがOpenAPI 3.1のオペレーションとして含まれ、以下の情報が付与されます。

- **パラメータ** — `param!`（rails\_param）宣言から抽出
- **リクエストボディ** — POST/PUT/PATCHの`param!`ブロックから推論
- **レスポンススキーマ** — jbuilderテンプレート、インライン`render json:`、または`.schema.json`サイドカーから導出
- **ステータスコード** — `head`、`render status:`、`redirect_to`の呼び出しから読み取り
- **エラーレスポンス** — `rescue_from`宣言から自動収集
- **サマリーと説明** — コントローラアクションのYARDコメントから取得

## なぜ静的解析なのか

静的解析によって、仕様は常にソースコードと同期します。「記録モード」のような不安定な仕組みも、マイグレーションの実行も、テストDBのシードも不要です。CIで`rake openapi:generate`を実行し、出力をdiffするだけです。

## クイックルック

```sh
# Gemfile
gem "rails-openapi-generator"

bundle install
bundle exec rake openapi:generate
# → doc/openapi.json
```

まずは[インストール](getting-started/installation.md)から始めましょう。

## ナビゲーション

- **はじめに** — インストール、設定、最初の生成まで
- **機能** — パラメータ、レスポンス、ステータスコードなどの詳細解説
- **ガイド** — スキーマサイドカー、ルートフィルタリング、ドキュメントのプレビュー、プログラム的利用
- **リファレンス** — 設定オプションの完全一覧
- **サンプル** — 実際のコントローラ・ビューを使ったエンドツーエンドの例
