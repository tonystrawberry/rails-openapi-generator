# HTMLページとファイルダウンロード

すべてのエンドポイントがJSONを返すわけではありません。ジェネレーターはHTMLページのレンダーとファイルダウンロードのレスポンスを認識し、spec内で適切に分類します。

## HTMLページ

アクションが`.html.*`ビューファイルに解決されるテンプレートをレンダーする場合、レスポンスはHTMLページレスポンスとして分類されます。

```ruby
class PagesController < ApplicationController
  def home
    render :home   # → app/views/pages/home.html.erbに解決
  end
end
```

→ 以下のレスポンスエントリが生成されます。

- `content-type`: `text/html`
- OpenAPIタグ: `"HTML Pages"`
- 拡張: `x-renders-html: true`
- ボディスキーマなし（HTMLは機械読み取り不可）

HTMLページのオペレーションはレンダリングされたドキュメント内で別の`"HTML Pages"`タグの下にグループ化され、APIエンドポイントと区別しやすくなります。

## ファイルダウンロード

アクションが`send_file`または`send_data`を呼び出す場合（直接または ヘルパーラッパー経由）、レスポンスはファイルダウンロードとして分類されます。

```ruby
def download
  send_file Rails.root.join("storage", params[:filename]),
            disposition: :attachment
end
```

→ 以下のレスポンスエントリが生成されます。

- `content-type`: `application/octet-stream`
- OpenAPIタグ: `"File Downloads"`
- 拡張: `x-sends-file: true`
- ボディスキーマなし

### ヘルパーラッパー

ジェネレーターは`send_file`/`send_data`の呼び出しを`method_resolution_depth`レベルまで追跡します。

```ruby
def export
  deliver_csv_attachment("users.csv", User.all.to_csv)
end

private

def deliver_csv_attachment(filename, content)
  send_data content, filename: filename, type: "text/csv", disposition: :attachment
end
```

→ `send_data`がヘルパー内にあっても、`export`はファイルダウンロードとして分類されます。

## 混合レスポンス（respond\_to）

アクションが`respond_to`を使って複数のコンテンツタイプを提供する場合、すべてのアクティブなブランチが1つのステータスコード下にまとめられます。

```ruby
def show
  respond_to do |format|
    format.json { render json: @user }
    format.html
  end
end
```

→ `200`レスポンスエントリに2つのコンテンツタイプエントリ: `application/json`（スキーマあり）と`text/html`。

## リダイレクト

[ステータスコード → リダイレクト](status-codes.md#リダイレクト)を参照してください。リダイレクトは適切な3xxステータスコードとボディスキーマなしのレスポンスエントリを生成します。
