# frozen_string_literal: true

require "fileutils"
require "json"

RSpec.describe RailsOpenapiGenerator::SchemaSidecarLoader do
  let(:tmp_root) { File.expand_path("../../tmp/spec/sidecars", __dir__) }
  let(:report)   { instance_double(RailsOpenapiGenerator::GenerationReport, warn: nil) }

  subject(:loader) { described_class.new(report: report) }

  before { FileUtils.mkdir_p(tmp_root) }
  after  { FileUtils.rm_rf(File.expand_path("../../tmp/spec", __dir__)) }

  def write(name, content)
    path = File.join(tmp_root, name)
    File.write(path, content)
    path
  end

  describe "#for_jbuilder" do
    it "returns the sibling sidecar's parsed contents when present" do
      jbuilder = write("_user.json.jbuilder", "json.id user.id")
      write("_user.schema.json", JSON.generate("type" => "object", "properties" => { "id" => { "type" => "integer" } }))

      expect(loader.for_jbuilder(jbuilder)).to eq(
        "type" => "object", "properties" => { "id" => { "type" => "integer" } }
      )
    end

    it "returns nil when no sibling sidecar exists" do
      jbuilder = write("show.json.jbuilder", "json.id @id")
      expect(loader.for_jbuilder(jbuilder)).to be_nil
    end

    it "returns nil for a path that is not a `.json.jbuilder` template" do
      expect(loader.for_jbuilder("/no/such/path.txt")).to be_nil
    end

    it "warns and returns nil for a malformed sidecar" do
      jbuilder = write("_broken.json.jbuilder", "json.id 1")
      write("_broken.schema.json", "{ broken")

      expect(report).to receive(:warn).with(/_broken\.schema\.json.*failed to parse/)
      expect(loader.for_jbuilder(jbuilder)).to be_nil
    end

    it "caches the parsed sidecar across repeated lookups" do
      jbuilder = write("_cached.json.jbuilder", "json.id 1")
      path = write("_cached.schema.json", JSON.generate("type" => "object"))
      first  = loader.for_jbuilder(jbuilder)
      File.write(path, "{ this would now break }")
      second = loader.for_jbuilder(jbuilder)

      expect(first).to equal(second)
    end
  end

  describe "cross-file `$ref` resolution" do
    subject(:loader) { described_class.new(report: report, views_root: tmp_root) }

    it "inlines a file-path ref under `$defs` and rewrites it to `#/$defs/<Name>`" do
      write("_image.schema.json", JSON.generate(
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        "type" => "object",
        "properties" => { "id" => { "type" => "integer" } }
      ))
      jbuilder = write("show.json.jbuilder", "json.id 1")
      write("show.schema.json", JSON.generate(
        "type" => "object",
        "properties" => {
          "images" => { "type" => "array", "items" => { "$ref" => "_image.schema.json" } }
        }
      ))

      result = loader.for_jbuilder(jbuilder)

      expect(result.dig("properties", "images", "items")).to eq("$ref" => "#/$defs/Image")
      expect(result["$defs"]).to eq(
        "Image" => { "type" => "object", "properties" => { "id" => { "type" => "integer" } } }
      )
    end

    it "resolves a views-root-relative ref path (camelizing the file name)" do
      FileUtils.mkdir_p(File.join(tmp_root, "api/maisokus"))
      File.write(File.join(tmp_root, "api/maisokus/_positioned_element.schema.json"),
                 JSON.generate("type" => "object", "properties" => { "x" => { "type" => "number" } }))
      File.write(File.join(tmp_root, "api/maisokus/show.schema.json"), JSON.generate(
        "type" => "object",
        "properties" => {
          "els" => { "type" => "array", "items" => { "$ref" => "api/maisokus/_positioned_element.schema.json" } }
        }
      ))

      result = loader.for_view(tmp_root, "api/maisokus", "show")

      expect(result.dig("properties", "els", "items")).to eq("$ref" => "#/$defs/PositionedElement")
      expect(result["$defs"]).to have_key("PositionedElement")
    end

    it "reuses one `$defs` entry when the same file is referenced more than once" do
      write("_image.schema.json", JSON.generate("type" => "object"))
      jbuilder = write("show.json.jbuilder", "json.id 1")
      write("show.schema.json", JSON.generate(
        "type" => "object",
        "properties" => {
          "a" => { "$ref" => "_image.schema.json" },
          "b" => { "$ref" => "_image.schema.json" }
        }
      ))

      result = loader.for_jbuilder(jbuilder)

      expect(result["$defs"].keys).to eq(["Image"])
      expect(result.dig("properties", "a")).to eq("$ref" => "#/$defs/Image")
      expect(result.dig("properties", "b")).to eq("$ref" => "#/$defs/Image")
    end

    it "resolves nested file refs transitively" do
      write("_leaf.schema.json", JSON.generate("type" => "object", "properties" => { "v" => { "type" => "string" } }))
      write("_branch.schema.json", JSON.generate(
        "type" => "object",
        "properties" => { "leaf" => { "$ref" => "_leaf.schema.json" } }
      ))
      jbuilder = write("show.json.jbuilder", "json.id 1")
      write("show.schema.json", JSON.generate(
        "type" => "object",
        "properties" => { "branch" => { "$ref" => "_branch.schema.json" } }
      ))

      result = loader.for_jbuilder(jbuilder)

      expect(result.dig("properties", "branch")).to eq("$ref" => "#/$defs/Branch")
      # The leaf is inlined inside the branch definition's own `$defs`,
      # which SchemaHoister later lifts into components.
      expect(result.dig("$defs", "Branch", "properties", "leaf")).to eq("$ref" => "#/$defs/Leaf")
      expect(result.dig("$defs", "Branch", "$defs")).to have_key("Leaf")
    end

    it "raises when a file ref cannot be resolved to an existing file" do
      jbuilder = write("show.json.jbuilder", "json.id 1")
      write("show.schema.json", JSON.generate(
        "type" => "object",
        "properties" => { "missing" => { "$ref" => "_nope.schema.json" } }
      ))

      expect { loader.for_jbuilder(jbuilder) }
        .to raise_error(RailsOpenapiGenerator::Error, /could not be resolved/)
    end

    it "raises on a circular file ref" do
      write("_a.schema.json", JSON.generate("type" => "object", "properties" => { "b" => { "$ref" => "_b.schema.json" } }))
      write("_b.schema.json", JSON.generate("type" => "object", "properties" => { "a" => { "$ref" => "_a.schema.json" } }))
      jbuilder = write("_a.json.jbuilder", "json.id 1")

      expect { loader.for_jbuilder(jbuilder) }
        .to raise_error(RailsOpenapiGenerator::Error, /circular/)
    end
  end

  describe "#for_view" do
    it "returns the sidecar at `<views_root>/<controller>/<action>.schema.json`" do
      FileUtils.mkdir_p(File.join(tmp_root, "api/users"))
      File.write(File.join(tmp_root, "api/users/show.schema.json"),
                 JSON.generate("type" => "object", "properties" => { "id" => { "type" => "integer" } }))

      expect(loader.for_view(tmp_root, "api/users", "show")).to eq(
        "type" => "object", "properties" => { "id" => { "type" => "integer" } }
      )
    end

    it "returns nil when no sidecar exists at the view path" do
      expect(loader.for_view(tmp_root, "api/users", "missing")).to be_nil
    end

    it "returns nil when any of views_root / controller / action is nil" do
      expect(loader.for_view(nil, "api/users", "show")).to be_nil
      expect(loader.for_view(tmp_root, nil, "show")).to be_nil
      expect(loader.for_view(tmp_root, "api/users", nil)).to be_nil
    end
  end
end
