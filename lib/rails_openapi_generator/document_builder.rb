# frozen_string_literal: true

module RailsOpenapiGenerator
  # Assembles a complete OpenAPI 3.1 document Hash from a set of {Endpoint}s.
  class DocumentBuilder
    OPENAPI_VERSION = "3.1.0"
    METHOD_ORDER    = %w[get post put patch delete].freeze
    LOCATION_ORDER  = { path: 0, query: 1, body: 2 }.freeze
    KIND_TAGS       = { html_page: "HTML Pages", file_download: "File Downloads" }.freeze

    def initialize(configuration)
      @configuration = configuration
    end

    # Returns the OpenAPI document Hash with deterministically ordered contents.
    def build(endpoints)
      document = {
        "openapi" => OPENAPI_VERSION,
        "info" => info
      }
      tags = tags(endpoints)
      document["tags"] = tags unless tags.empty?
      document["paths"] = paths(endpoints)
      SchemaHoister.new.hoist!(document)
    end

    private

    # One OpenAPI tag per controller, plus the "HTML Pages" / "File Downloads"
    # kind tags, so viewers group operations meaningfully.
    def tags(endpoints)
      names = endpoints.flat_map { |endpoint| operation_tags(endpoint) }
      names.uniq.sort.map { |name| { "name" => name } }
    end

    # The tags for one operation: its controller tag plus, for a non-JSON
    # endpoint, the kind tag ("HTML Pages" / "File Downloads").
    def operation_tags(endpoint)
      tags = []
      tags << endpoint.tag if endpoint.tag
      kind_tag = KIND_TAGS[endpoint.response&.kind]
      tags << kind_tag if kind_tag
      tags
    end

    def info
      {
        "title" => @configuration.title || default_title,
        "version" => @configuration.api_version
      }
    end

    def default_title
      return "API" unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

      Rails.application.class.name.to_s.split("::").first || "API"
    rescue StandardError
      "API"
    end

    def paths(endpoints)
      grouped = Hash.new { |hash, key| hash[key] = {} }

      endpoints.sort_by { |endpoint| [endpoint.path, endpoint.http_method] }.each do |endpoint|
        grouped[openapi_path(endpoint.path)][endpoint.http_method.downcase] = operation(endpoint)
      end

      grouped.keys.sort.to_h do |path|
        [path, sort_by_method(grouped[path])]
      end
    end

    # Converts Rails `:id` / `*splat` segments to OpenAPI `{id}` syntax.
    def openapi_path(path)
      path.gsub(/[:*]([A-Za-z_][A-Za-z0-9_]*)/) { "{#{Regexp.last_match(1)}}" }
    end

    def sort_by_method(operations)
      operations.keys.sort_by { |method| METHOD_ORDER.index(method) || METHOD_ORDER.size }
                .to_h { |method| [method, operations[method]] }
    end

    def operation(endpoint)
      result = { "operationId" => endpoint.operation_id }
      tags = operation_tags(endpoint)
      result["tags"]        = tags unless tags.empty?
      result["summary"]     = endpoint.summary if endpoint.summary
      result["description"] = endpoint.description if endpoint.description
      result.merge!(kind_extensions(endpoint.response))

      parameters = endpoint.parameters.reject { |param| param.location == :body }
      result["parameters"]  = sorted_parameters(parameters) unless parameters.empty?
      result["requestBody"] = endpoint.request_body if endpoint.request_body
      result["responses"]   = responses(endpoint.response)
      result
    end

    # Machine-readable vendor extensions marking a non-JSON endpoint.
    def kind_extensions(response)
      case response&.kind
      when :html_page
        extensions = { "x-renders-html" => true }
        extensions["x-html-template"] = response.page_reference if response.page_reference
        extensions
      when :file_download
        { "x-sends-file" => true }
      else
        {}
      end
    end

    # Builds the OpenAPI `responses` object from the endpoint's success response.
    # Iterates `response.entries` so a multi-status JSON operation emits one
    # key per entry, ascending by numeric status.
    def responses(response)
      response.entries.each_with_object({}) do |entry, map|
        out = { "description" => response.description }
        content = entry_content(response, entry)
        out["content"] = content if content
        map[entry.status.to_s] = out
      end
    end

    # The response content type and schema for one entry, by response kind.
    # A `:redirect` response has no body, so no content entry is emitted.
    # When the entry carries a `content_types` map (feature 012 — a
    # `respond_to` block with multiple format gates), emit one OpenAPI
    # content entry per content type, sorted alphabetically.
    def entry_content(response, entry)
      return content_types_map(entry.content_types) if entry.content_types

      case response.kind
      when :html_page
        { "text/html" => { "schema" => { "type" => "string" } } }
      when :file_download
        { "application/octet-stream" => { "schema" => { "type" => "string", "format" => "binary" } } }
      when :redirect
        nil
      else
        entry.body ? { "application/json" => { "schema" => entry.body } } : nil
      end
    end

    def content_types_map(content_types)
      content_types.sort.to_h do |content_type, body|
        schema = body || { "type" => "string" }
        [content_type, { "schema" => schema }]
      end
    end

    def sorted_parameters(parameters)
      parameters
        .sort_by { |param| [LOCATION_ORDER.fetch(param.location, 9), param.name] }
        .map { |param| parameter_object(param) }
    end

    def parameter_object(param)
      object = { "name" => param.name, "in" => param.location.to_s, "required" => param.required }
      object["description"] = param.description if param.description
      object["schema"] = param.schema
      object
    end
  end
end
