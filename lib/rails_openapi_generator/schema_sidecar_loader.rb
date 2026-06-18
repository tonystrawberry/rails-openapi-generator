# frozen_string_literal: true

require "json"

module RailsOpenapiGenerator
  # Loads JSON Schema sidecar files that sit next to jbuilder templates
  # or at the conventional view path for an action. The sidecar's
  # contents are returned verbatim as the OpenAPI body schema, replacing
  # the parser's inference.
  #
  # Two lookup modes:
  #   - {#for_jbuilder}: sibling of a `.json.jbuilder` template.
  #     `app/views/api/users/_user.json.jbuilder`
  #     → `app/views/api/users/_user.schema.json`
  #   - {#for_view}: action's conventional view path.
  #     `(views_root, "api/users", "show")`
  #     → `<views_root>/api/users/show.schema.json`
  #
  # Cross-file references: a sidecar may point at another sidecar with a
  # file-path `$ref` (e.g. `"api/users/_user.schema.json"` or
  # `"./_user.schema.json"`) instead of inlining a shared shape. Such
  # refs are resolved at load time: the target sidecar is loaded,
  # inlined under the document's `$defs`, and the ref rewritten to
  # `#/$defs/<Name>`. {SchemaHoister} then lifts those defs into
  # `components/schemas`. Without this step the file path would survive
  # verbatim into the OpenAPI document and downstream tooling (Redocly)
  # fails with "Invalid JSON pointer". An unresolvable file ref raises so
  # the problem surfaces at generate time rather than as a broken doc.
  #
  # Malformed sidecars (invalid JSON) emit a warning via the optional
  # `report` collaborator and fall back to nil so the caller uses its
  # inferred schema. Lookups are cached for the loader's lifetime.
  class SchemaSidecarLoader
    JBUILDER_EXTENSION = ".json.jbuilder"
    SIDECAR_EXTENSION  = ".schema.json"

    # A `$ref` value that points at another sidecar file rather than a
    # JSON Pointer fragment (`#/...`). Bare or relative file paths ending
    # in `.schema.json` are treated as cross-file references.
    FILE_REF = /#{Regexp.escape(SIDECAR_EXTENSION)}\z/

    def initialize(report: nil, views_root: nil)
      @report     = report
      @views_root = views_root
      @cache      = {}
    end

    # Returns the sidecar schema Hash for a jbuilder template path, or
    # nil when no sidecar exists at the sibling location.
    def for_jbuilder(jbuilder_path)
      return nil if jbuilder_path.nil? || !jbuilder_path.end_with?(JBUILDER_EXTENSION)

      load_path(sibling_sidecar_path(jbuilder_path))
    end

    # Returns the sidecar schema Hash for an action's conventional view
    # path (`<views_root>/<controller>/<action>.schema.json`), or nil
    # when no sidecar exists.
    def for_view(views_root, controller, action)
      return nil if views_root.nil? || controller.nil? || action.nil?

      load_path(File.join(views_root, "#{controller}/#{action}#{SIDECAR_EXTENSION}"))
    end

    private

    def sibling_sidecar_path(jbuilder_path)
      jbuilder_path.sub(/#{Regexp.escape(JBUILDER_EXTENSION)}\z/, SIDECAR_EXTENSION)
    end

    def load_path(path)
      return nil if path.nil? || !File.file?(path)
      return @cache[path] if @cache.key?(path)

      @cache[path] = parse_sidecar(path)
    end

    def parse_sidecar(path)
      schema = JSON.parse(File.read(path))
      resolve_file_refs!(schema, path)
      schema
    rescue JSON::ParserError => e
      @report&.warn("schema sidecar `#{path}` failed to parse: #{e.message}")
      nil
    end

    # Walks `root`, inlining every cross-file `$ref` under a `$defs` block
    # on `root` and rewriting the ref to `#/$defs/<Name>`. `stack` holds
    # the absolute paths currently being resolved, for cycle detection.
    def resolve_file_refs!(root, root_path, stack = [])
      defs = root["$defs"].is_a?(Hash) ? root["$defs"] : {}
      inline_file_refs(root, root_path, defs, stack)
      root["$defs"] = defs unless defs.empty?
      root
    end

    def inline_file_refs(node, base_path, defs, stack)
      case node
      when Hash
        ref = node["$ref"]
        node["$ref"] = "#/$defs/#{inline_target(ref, base_path, defs, stack)}" if file_ref?(ref)
        # Snapshot values so inlining (which adds keys to `defs`) cannot
        # mutate a hash mid-iteration when `node` is the `$defs` block.
        node.values.each { |value| inline_file_refs(value, base_path, defs, stack) }
      when Array
        node.each { |value| inline_file_refs(value, base_path, defs, stack) }
      end
    end

    # Loads the sidecar named by `ref`, resolves its own cross-file refs,
    # adds it to `defs`, and returns the chosen definition name.
    def inline_target(ref, base_path, defs, stack)
      target_path = resolve_ref_path(ref, base_path)
      unless target_path && File.file?(target_path)
        raise Error, "schema sidecar `#{base_path}` references `#{ref}`, " \
                     "which could not be resolved to an existing `.schema.json` file"
      end
      if stack.include?(target_path)
        raise Error, "circular schema sidecar reference: #{(stack + [target_path]).join(" -> ")}"
      end

      target = JSON.parse(File.read(target_path))
      resolve_file_refs!(target, target_path, stack + [target_path])
      target.delete("$schema")
      allocate_def(defs, definition_name(target_path), target)
    end

    # Resolves a file-path ref against the referencing sidecar's own
    # directory first, then the views root — mirroring how jbuilder
    # partials are looked up.
    def resolve_ref_path(ref, base_path)
      candidates = [File.expand_path(ref, File.dirname(base_path))]
      candidates << File.expand_path(ref, @views_root) if @views_root
      candidates.find { |path| File.file?(path) }
    end

    # Adds `schema` to `defs` under `name`, reusing the key when an
    # identical schema is already present and suffixing (`User_2`) when a
    # differently-shaped definition already holds the name. Returns the
    # key used. Matches {SchemaHoister}'s collision policy.
    def allocate_def(defs, name, schema)
      candidate = name
      suffix = 2
      while defs.key?(candidate) && defs[candidate] != schema
        candidate = "#{name}_#{suffix}"
        suffix += 1
      end
      defs[candidate] = schema
      candidate
    end

    # Derives a PascalCase definition name from a sidecar path:
    # `.../_positioned_element.schema.json` → `PositionedElement`.
    def definition_name(path)
      base = File.basename(path, SIDECAR_EXTENSION).sub(/\A_/, "")
      base.split(/[_\s-]+/).map(&:capitalize).join
    end

    def file_ref?(ref)
      ref.is_a?(String) && !ref.start_with?("#") && ref.match?(FILE_REF)
    end
  end
end
