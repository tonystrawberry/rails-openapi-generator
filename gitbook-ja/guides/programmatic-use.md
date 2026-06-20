# プログラム的利用

ジェネレーターはrakeやCLI以外での利用のためにRuby APIを公開しています。テスト、ツール統合、動的なspec配信などに便利です。

## 生成してディスクに書き出す

```ruby
require "rails_openapi_generator"

config = RailsOpenapiGenerator::Configuration.new
config.output_path = "doc/openapi.json"
config.title       = "My API"
config.api_version = "1.0.0"

report = RailsOpenapiGenerator::Generator.new(config).generate
```

`generate`はファイルを`config.output_path`に書き出し、`GenerationReport`を返します。

## ドキュメントをメモリ上で取得

```ruby
document = RailsOpenapiGenerator::Generator.new(config).document
# => Hash — シリアライズされていない完全なOpenAPI 3.1ドキュメント
```

書き出す前にドキュメントを後処理する場合に使います。

```ruby
doc = RailsOpenapiGenerator::Generator.new(config).document

# セキュリティスキームを追加
doc["components"] ||= {}
doc["components"]["securitySchemes"] = {
  "bearerAuth" => {
    "type" => "http",
    "scheme" => "bearer",
    "bearerFormat" => "JWT"
  }
}

# グローバルに適用
doc["security"] = [{ "bearerAuth" => [] }]

File.write("doc/openapi.json", JSON.pretty_generate(doc))
```

## 生成レポートの読み取り

```ruby
report = RailsOpenapiGenerator::Generator.new(config).generate

puts "処理済み: #{report.processed_count}"
puts "スキップ: #{report.skipped_count}"

report.skipped.each do |item|
  puts "  - #{item.verb} #{item.path}: #{item.reason}"
end

report.warnings.each do |warning|
  puts "警告: #{warning}"
end
```

## デフォルト設定を使う

`config/initializers/rails_openapi_generator.rb`がすでにある場合は、設定済みのインスタンスを直接使えます。

```ruby
generator = RailsOpenapiGenerator::Generator.new(RailsOpenapiGenerator.configuration)
generator.generate
```

## コントローラからspecを配信する

```ruby
class Api::DocsController < ApplicationController
  def show
    config = RailsOpenapiGenerator.configuration
    document = RailsOpenapiGenerator::Generator.new(config).document
    render json: document
  end
end
```

注意: 大規模アプリでリクエストごとにspecを生成すると遅くなります。結果をキャッシュしましょう。

```ruby
def show
  spec = Rails.cache.fetch("openapi_spec", expires_in: 1.hour) do
    RailsOpenapiGenerator::Generator.new(RailsOpenapiGenerator.configuration).document
  end
  render json: spec
end
```

## RSpecとの統合

変更後もspecが有効なままかテストできます。

```ruby
# spec/openapi_spec.rb
require "rails_helper"
require "json_schemer"

RSpec.describe "OpenAPI spec" do
  let(:document) do
    config = RailsOpenapiGenerator::Configuration.new
    config.output_path = Rails.root.join("doc/openapi.json").to_s
    RailsOpenapiGenerator::Generator.new(config).document
  end

  it "有効なOpenAPI 3.1であること" do
    meta_schema = JSONSchemer.openapi31
    errors = meta_schema.validate(document).to_a
    expect(errors).to be_empty, errors.map { |e| e["error"] }.join("\n")
  end

  it "生成に警告がないこと" do
    config = RailsOpenapiGenerator::Configuration.new
    report = RailsOpenapiGenerator::Generator.new(config).generate
    expect(report.warnings).to be_empty
  end
end
```
