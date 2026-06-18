# frozen_string_literal: true

module RailsOpenapiGenerator
  # Orchestrates the pipeline: routes -> operations -> OpenAPI document -> file.
  class Generator
    def initialize(configuration = RailsOpenapiGenerator.configuration)
      @configuration = configuration
    end

    # Builds the document, writes it, and returns a {GenerationReport}.
    def generate
      @configuration.validate!
      document = build_document
      @report.output_path = Writer.new(@configuration).write(document)
      @report
    end

    # Builds and returns the OpenAPI document Hash without writing a file.
    def document
      @configuration.validate!
      build_document
    end

    private

    def build_document
      @report = GenerationReport.new
      setup_pipeline
      endpoints = routes_to_process.filter_map { |route| build_endpoint(route) }
      DocumentBuilder.new(@configuration).build(endpoints)
    end

    def setup_pipeline
      views_root = views_root_path
      LiteralEvaluator.resolver = ConstantResolver.new
      @locator          = SourceLocator.new
      @parser           = YardParser.new
      @param_extractor  = ParamExtractor.new
      @doc_extractor    = DocCommentExtractor.new
      @render_extractor = RenderExtractor.new
      @view_locator     = ViewLocator.new(views_root: views_root)
      @sidecar_loader   = SchemaSidecarLoader.new(report: @report, views_root: views_root)
      @jbuilder_parser  = JbuilderParser.new(views_root: views_root, sidecar_loader: @sidecar_loader)
      @views_root       = views_root
      @method_resolver  = MethodResolver.new(yard_parser: @parser)
      @walker           = ControllerMethodWalker.new(
        method_resolver: @method_resolver, max_depth: @configuration.method_resolution_depth
      )
      @helper_binding_walker = HelperBindingWalker.new(
        method_resolver: @method_resolver, max_depth: @configuration.method_resolution_depth
      )
      @wrapper_resolver = WrapperDownloadResolver.new(walker: @walker)
      @implicit_scanner = ImplicitParamScanner.new(walker: @walker)
      @before_action_resolver = BeforeActionResolver.new(method_resolver: @method_resolver)
      @rescue_from_resolver   = RescueFromResolver.new(method_resolver: @method_resolver)
      @classifier       = RenderClassifier.new(view_locator: @view_locator, wrapper_resolver: @wrapper_resolver)
      @response_builder = ResponseBuilder.new
      @operation_builder = OperationBuilder.new
    end

    def routes_to_process
      RouteCollector.new(route_filter: @configuration.route_filter).collect.filter_map do |route|
        if route.resolvable?
          route
        else
          @report.skip(route, "no backing controller action")
          nil
        end
      end
    end

    def build_endpoint(route)
      file = locate_source(route)
      if @configuration.source_excluded?(file)
        @report.skip(route, "controller source excluded by exclude_source_paths")
        return nil
      end

      action_source    = file && @parser.parse(file)[route.action]
      action_node      = action_source&.method_node
      controller_class = @locator.controller_class(route)
      param_calls      = @param_extractor.extract(action_source)
      warn_unresolved(route, param_calls)

      response = build_response(route, action_source, controller_class)
      count_kind(response)
      endpoint = @operation_builder.build(
        route,
        doc_comment: @doc_extractor.extract(action_source),
        param_calls: param_calls,
        source_location: source_location_for(file, action_source),
        response: response,
        implicit_params: @implicit_scanner.scan(controller_class, action_node)
      )
      @report.processed_count += 1
      endpoint
    rescue StandardError => e
      @report.warn("#{route.http_method} #{route.path}: #{e.message}")
      @report.processed_count += 1
      @operation_builder.build(route)
    end

    def build_response(route, action_source, controller_class)
      render_result = @render_extractor.extract(action_source)
      resolve_template_sites!(render_result.render_sites, route)
      classification = @classifier.classify(
        route, render_result,
        controller_class: controller_class,
        action_node: action_source&.method_node
      )
      view_schema    = classification.jbuilder_file ? @jbuilder_parser.parse(classification.jbuilder_file) : nil
      extra_sites    = collect_extra_sites(route, controller_class, action_source)
      resolve_template_sites!(extra_sites, route)
      response = @response_builder.build(
        route, classification: classification, view_schema: view_schema, extra_sites: extra_sites
      )

      apply_action_sidecar!(response, route)

      if response.undeterminable?
        @report.warn("#{route.http_method} #{route.path}: response shape could not be determined")
      end
      response
    end

    # When a sidecar exists at the action's conventional view path
    # (`<views_root>/<controller>/<action>.schema.json`), use it as the
    # authoritative body for the HTTP-method convention status entry,
    # overriding what was inferred from a jbuilder template or an inline
    # `render json:` (feature 020 US2). JSON-kind responses only —
    # html_page / file_download / redirect ignore sidecars per FR-007.
    def apply_action_sidecar!(response, route)
      return unless response.kind == :json

      schema = @sidecar_loader.for_view(@views_root, route.controller, route.action)
      return if schema.nil?

      convention = ResponseBuilder::STATUS_BY_METHOD.fetch(route.http_method, ResponseBuilder::DEFAULT_STATUS)
      entry = response.entries.find { |e| e.status == convention }
      if entry.nil?
        response.entries << ResponseEntry.new(status: convention, body: schema)
        response.entries.sort_by!(&:status)
      else
        entry.body = schema
        entry.content_types = nil
      end
      response.undeterminable = false
    end

    # Resolves every unresolved template-render site in `sites` (mutates
    # each in place): looks up the view via {ViewLocator} with the site's
    # `format_hint`, then either parses the jbuilder (JSON site with
    # schema), marks the site as an HTML-template site, or leaves it as a
    # body-less JSON site (status known, body unknown).
    def resolve_template_sites!(sites, route)
      Array(sites).each do |site|
        next unless site&.template?

        # A `respond_to` format gate without an inline render uses the
        # sentinel as its template name; expand to the action's default
        # view path (`<controller>/<action>`) before lookup runs.
        if site.template_name == RenderExtractor::SENTINEL_DEFAULT_VIEW
          site.template_name = "#{route.controller}/#{route.action}"
        end

        view = @view_locator.locate_view(route, site.template_name, format_hint: site.format_hint)
        case view&.kind
        when :json
          site.schema = @jbuilder_parser.parse(view.path)
        when :html
          site.kind_hint = :html_page
        end
        site.template_name = nil
        site.format_hint = nil
      end
    end

    # Render sites reached through helper methods called from the action,
    # and through `before_action` callbacks applicable to this action.
    # JSON-only — non-JSON kinds (redirect / file / html) are unchanged
    # by feature 010 and ignore extras.
    def collect_extra_sites(route, controller_class, action_source)
      action_node = action_source&.method_node
      return [] if action_node.nil? || controller_class.nil?

      helper_sites = helper_render_sites(controller_class, action_node)
      callback_sites = before_action_render_sites(controller_class, route.action)
      rescue_sites = rescue_from_render_sites(controller_class)
      helper_sites + callback_sites + rescue_sites
    end

    def rescue_from_render_sites(controller_class)
      handlers = @rescue_from_resolver.resolve(controller_class)
      handlers.flat_map { |handler| sites_from_callback(controller_class, handler.method_node, :rescue_from) }
    end

    def helper_render_sites(controller_class, action_node)
      # The binding walker excludes the action body itself — that body's
      # render sites are already collected by RenderExtractor#extract.
      bodies = @helper_binding_walker.reachable_bodies(controller_class, action_node)
      bodies.flat_map { |body| @render_extractor.collect_sites(body, source: :helper) }
    end

    def before_action_render_sites(controller_class, action_name)
      callbacks = @before_action_resolver.resolve(controller_class)
      applicable = callbacks.select { |callback| callback.applies_to?(action_name) }
      applicable.flat_map { |callback| sites_from_callback(controller_class, callback.method_node, :before_action) }
    end

    # Renders contributed by a Rails-invoked callback (before_action or
    # rescue_from handler): the callback body itself (no inferred
    # bindings — Rails calls it) plus every helper it reaches, walked
    # with argument propagation (feature 018).
    def sites_from_callback(controller_class, method_node, source)
      own_sites = @render_extractor.collect_sites(method_node, source: source)
      helper_bodies = @helper_binding_walker.reachable_bodies(controller_class, method_node)
      own_sites + helper_bodies.flat_map { |body| @render_extractor.collect_sites(body, source: source) }
    end

    def count_kind(response)
      @report.html_page_count += 1 if response.kind == :html_page
      @report.file_download_count += 1 if response.kind == :file_download
    end

    def locate_source(route)
      file = @locator.locate(route)
      @report.warn("#{route.http_method} #{route.path}: controller source not found") if file.nil?
      file
    end

    def views_root_path
      return nil unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

      File.join(Rails.root.to_s, "app", "views")
    rescue StandardError
      nil
    end

    # A "path:line" reference (relative to the Rails root) to the action's source.
    def source_location_for(file, action_source)
      return nil if file.nil?

      relative = relative_path(file)
      line = action_source&.line
      line ? "#{relative}:#{line}" : relative
    end

    def relative_path(file)
      root = (Rails.root.to_s if defined?(Rails) && Rails.respond_to?(:root) && Rails.root)
      root && file.start_with?("#{root}/") ? file.delete_prefix("#{root}/") : file
    end

    def warn_unresolved(route, param_calls)
      param_calls.reject(&:fully_resolved?).each do |call|
        name = call.name || "a parameter"
        @report.warn("#{route.http_method} #{route.path}: non-literal param! arguments for #{name}")
      end
    end
  end
end
