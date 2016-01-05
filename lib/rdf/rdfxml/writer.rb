require 'rdf/rdfa'

module RDF::RDFXML
  ##
  # An RDF/XML serialiser in Ruby
  #
  # Note that the natural interface is to write a whole graph at a time.
  # Writing statements or Triples will create a graph to add them to
  # and then serialize the graph.
  #
  # The writer will add prefix definitions, and use them for creating @prefix definitions, and minting QNames
  #
  # @example Obtaining a RDF/XML writer class
  #   RDF::Writer.for(:rdf)         #=> RDF::RDFXML::Writer
  #   RDF::Writer.for("etc/test.rdf")
  #   RDF::Writer.for(file_name: "etc/test.rdf")
  #   RDF::Writer.for(file_extension: "rdf")
  #   RDF::Writer.for(content_type: "application/rdf+xml")
  #
  # @example Serializing RDF graph into an RDF/XML file
  #   RDF::RDFXML::Write.open("etc/test.rdf") do |writer|
  #     writer << graph
  #   end
  #
  # @example Serializing RDF statements into an RDF/XML file
  #   RDF::RDFXML::Writer.open("etc/test.rdf") do |writer|
  #     graph.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @example Serializing RDF statements into an RDF/XML string
  #   RDF::RDFXML::Writer.buffer do |writer|
  #     graph.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @example Creating @base and @prefix definitions in output
  #   RDF::RDFXML::Writer.buffer(base_uri: "http://example.com/", prefixes: {
  #       nil => "http://example.com/ns#",
  #       foaf: "http://xmlns.com/foaf/0.1/"}
  #   ) do |writer|
  #     graph.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Writer < RDF::RDFa::Writer
    format RDF::RDFXML::Format
    include RDF::Util::Logger

    VALID_ATTRIBUTES = [:none, :untyped, :typed]

    ##
    # RDF/XML Writer options
    # @see http://www.rubydoc.info/github/ruby-rdf/rdf/RDF/Writer#options-class_method
    def self.options
      super + [
        RDF::CLI::Option.new(
          symbol: :attributes,
          datatype: %w(none untyped typed),
          on: ["--attributes ATTRIBUTES",  %w(none untyped typed)],
          description: "How to use XML attributes when serializing, one of :none, :untyped, :typed. The default is :none.") {|arg| arg.to_sym},
        RDF::CLI::Option.new(
          symbol: :default_namespace,
          datatype: RDF::URI,
          on: ["--default-namespace URI", :REQUIRED],
          description: "URI to use as default namespace, same as prefixes.") {|arg| RDF::URI(arg)},
        RDF::CLI::Option.new(
          symbol: :lang,
          datatype: String,
          on: ["--lang"],
          description: "Output as root @lang attribute, and avoid generation _@lang_ where possible."),
        RDF::CLI::Option.new(
          symbol: :max_depth,
          datatype: Integer,
          on: ["--max-depth"],
          description: "Maximum depth for recursively defining resources, defaults to 3.") {|arg| arg.to_i},
        RDF::CLI::Option.new(
          symbol: :stylesheet,
          datatype: RDF::URI,
          on: ["--stylesheet URI", :REQUIRED],
          description: "URI to use as @href for output stylesheet processing instruction.") {|arg| RDF::URI(arg)},
      ]
    end

    ##
    # Initializes the RDF/XML writer instance.
    #
    # @param  [IO, File] output
    #   the output stream
    # @param  [Hash{Symbol => Object}] options
    #   any additional options
    # @option options [Boolean]  :canonicalize (false)
    #   whether to canonicalize literals when serializing
    # @option options [Hash]     :prefixes     (Hash.new)
    #   the prefix mappings to use (not supported by all writers)
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when constructing relative URIs
    # @option options [Integer]  :max_depth (10)
    #   Maximum depth for recursively defining resources
    # @option options [#to_s]   :lang   (nil)
    #   Output as root xml:lang attribute, and avoid generation _xml:lang_ where possible
    # @option options [Symbol]    :attributes   (nil)
    #   How to use XML attributes when serializing, one of :none, :untyped, :typed. The default is :none.
    # @option options [Boolean]  :standard_prefixes   (false)
    #   Add standard prefixes to _prefixes_, if necessary.
    # @option options [String]   :default_namespace (nil)
    #   URI to use as default namespace, same as prefix(nil)
    # @option options [String] :stylesheet (nil)
    #   URI to use as @href for output stylesheet processing instruction.
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      super
    end

    # @return [Hash<Symbol => String>]
    def haml_template
      return @haml_template if @haml_template
      case @options[:haml]
      when Hash             then @options[:haml]
      else                       DEFAULT_HAML
      end
    end

    def write_epilogue
      @force_RDF_about = {}
      @max_depth = @options.fetch(:max_depth, 10)
      @attributes = @options.fetch(:attributes, :none)

      super
    end

  protected
    # Render a subject using `haml_template[:subject]`.
    #
    # The _subject_ template may be called either as a top-level element, or recursively under another element if the _rel_ local is not nil.
    #
    #  For RDF/XML, removes from predicates those that can be rendered as attributes, and adds the `:attr_props` local for the Haml template, which includes all attributes to be rendered as properties.
    #
    # Yields each predicate/property to be rendered separately (@see #render_property_value and `#render_property_values`).
    #
    # @param [Array<RDF::Resource>] subject
    #   Subject to render
    # @param [Array<RDF::Resource>] predicates
    #   Predicates of subject. Each property is yielded for separate rendering.
    # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
    # @option options [String] about (nil)
    #   About description, a CURIE, URI or Node definition.
    #   May be nil if no @about is rendered (e.g. unreferenced Nodes)
    # @option options [String] resource (nil)
    #   Resource description, a CURIE, URI or Node definition.
    #   May be nil if no @resource is rendered
    # @option options [String] rel (nil)
    #   Optional @rel property description, a CURIE, URI or Node definition.
    # @option options [String] typeof (nil)
    #   RDF type as a CURIE, URI or Node definition.
    #   If :about is nil, this defaults to the empty string ("").
    # @option options [:li, nil] element (nil)
    #   Render with &lt;li&gt;, otherwise with template default.
    # @option options [String] haml (haml_template[:subject])
    #   Haml template to render.
    # @yield [predicate]
    #   Yields each predicate
    # @yieldparam [RDF::URI] predicate
    # @yieldreturn [:ignored]
    # @return String
    #   The rendered document is returned as a string
    # Return Haml template for document from `haml_template[:subject]`
    def render_subject(subject, predicates, options = {}, &block)
      # extract those properties that can be rendered as attributes
      attr_props = if [:untyped, :typed].include?(@attributes)
        options[:property_values].inject({}) do |memo, (prop, values)|
          object = values.first
          if values.length == 1 &&
            object.literal? &&
            (object.plain? || @attributes == :typed) &&
            get_lang(object).nil?

            memo[get_qname(RDF::URI(prop))] = object.value
          end
          memo
        end
      else
        {}
      end

      predicates -= attr_props.keys.map {|k| expand_curie(k).to_s}
      super(subject, predicates, options.merge(attr_props: attr_props), &block)
    end
    # See if we can serialize as attribute.
    # * untyped attributes that aren't duplicated where xml:lang == @lang
    # * typed attributes that aren't duplicated if @dt_as_attr is true
    # * rdf:type
    def predicate_as_attribute?(prop, object)
      [:untyped, :typed].include?(@attributes) && (
        prop == RDF.type ||
        [:typed].include?(@attributes) && object.literal? && object.typed? ||
        (object.literal? && object.simple? || @lang && object.language.to_s == @lang.to_s)
      )
    end

    # Render document using `haml_template[:doc]`. Yields each subject to be rendered separately.
    #
    # For RDF/XML pass along a stylesheet option.
    #
    # @param [Array<RDF::Resource>] subjects
    #   Ordered list of subjects. Template must yield to each subject, which returns
    #   the serialization of that subject (@see #subject_template)
    # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
    # @option options [RDF::URI] base (nil)
    #   Base URI added to document, used for shortening URIs within the document.
    # @option options [Symbol, String] language (nil)
    #   Value of @lang attribute in document, also allows included literals to omit
    #   an @lang attribute if it is equivalent to that of the document.
    # @option options [String] title (nil)
    #   Value of html>head>title element.
    # @option options [String] prefix (nil)
    #   Value of @prefix attribute.
    # @option options [String] haml (haml_template[:doc])
    #   Haml template to render.
    # @yield [subject]
    #   Yields each subject
    # @yieldparam [RDF::URI] subject
    # @yieldreturn [:ignored]
    # @return String
    #   The rendered document is returned as a string
    def render_document(subjects, options = {}, &block)
      super(subjects, options.merge(stylesheet: @options[:stylesheet]), &block)
    end

    # Render a single- or multi-valued predicate using `haml_template[:property_value]` or `haml_template[:property_values]`. Yields each object for optional rendering. The block should only render for recursive subject definitions (i.e., where the object is also a subject and is rendered underneath the first referencing subject).
    #
    # For RDF/XML, pass the `:no_list_literals` option onto the `RDFa` implementation because of special considerations for lists in RDF/XML.
    #
    # If a multi-valued property definition is not found within the template, the writer will use the single-valued property definition multiple times.
    #
    # @param [Array<RDF::Resource>] predicate
    #   Predicate to render.
    # @param [Array<RDF::Resource>] objects
    #   List of objects to render. If the list contains only a single element, the :property_value template will be used. Otherwise, the :property_values template is used.
    # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
    # @option options [String] :haml (haml_template[:property_value], haml_template[:property_values])
    #   Haml template to render. Otherwise, uses `haml_template[:property_value] or haml_template[:property_values]`
    #   depending on the cardinality of objects.
    # @option options [Boolean] :no_list_literals
    #   Do not serialize as a list if any elements are literal.
    # @yield object, inlist
    #   Yields object and if it is contained in a list.
    # @yieldparam [RDF::Resource] object
    # @yieldparam [Boolean] inlist
    # @yieldreturn [String, nil]
    #   The block should only return a string for recursive object definitions.
    # @return String
    #   The rendered document is returned as a string
    def render_property(predicate, objects, options = {}, &block)
      log_debug {"render_property(#{predicate}): #{objects.inspect}, #{options.inspect}"}
      # If there are multiple objects, and no :property_values is defined, call recursively with
      # each object

      template = options[:haml]
      template ||= haml_template[:property_value]

      # Separate out the objects which are lists and render separately
      lists = objects.
        select(&:node?).
        map {|o| RDF::List.new(subject: o, graph: @graph)}.
        select {|l| l.valid? && l.none?(&:literal?)}

      unless lists.empty?
        # Render non-list objects
        log_debug {"properties with lists: #{lists} non-lists: #{objects - lists.map(&:subject)}"}
        nl = log_depth {render_property(predicate, objects - lists.map(&:subject), options, &block)} unless objects == lists.map(&:subject)
        return nl.to_s + lists.map do |list|
          # Render each list as multiple properties and set :inlist to true
          list.each_statement {|st| subject_done(st.subject)}

          log_debug {"list: #{list.inspect} #{list.to_a}"}
          log_depth do
            render_collection(predicate, list, options) do |object|
              yield(object, true) if block_given?
            end
          end
        end.join(" ")
      end

      if objects.length > 1
        # Render each property using property_value template
        objects.map do |object|
          log_depth {render_property(predicate, [object], options, &block)}
        end.join(" ")
      else
        log_fatal("Missing property template", exception:  RDF::WriterError) if template.nil?

        options = {
          object:     objects.first,
          predicate:  predicate,
          property:   get_qname(predicate),
          recurse:    log_depth <= @max_depth
        }.merge(options)
        hamlify(template, options, &block)
      end
    end

    ##
    # Render a collection, which may be included in a property declaration, or
    # may be recursive within another collection
    #
    # @param [RDF::URI] predicate
    # @param [RDF::List] list
    # @param [Hash{Symbol => Object}] options
    # @yield object
    #   Yields object, unless it is an included list
    # @yieldparam [RDF::Resource] object
    # @yieldreturn [String, nil]
    #   The block should only return a string for recursive object definitions.
    # @return String
    #   The rendered collection is returned as a string
    def render_collection(predicate, list, options = {}, &block)
      template = options[:haml] || haml_template[:collection]

      options = {
        list:       list,
        predicate:  predicate,
        property:   get_qname(predicate),
        recurse:    log_depth <= @max_depth,
      }.merge(options)
      hamlify(template, options) do |object|
        yield object
      end
    end

    # XML namespace attributes for defined prefixes
    # @return [Hash{String => String}]
    def prefix_attrs
      prefixes.inject({}) do |memo, (k, v)|
        memo[k ? "xmlns:#{k}" : "xmlns"] = v.to_s
        memo
      end
    end

    # Perform any preprocessing of statements required
    # @return [ignored]
    def preprocess
      # Load defined prefixes
      (@options[:prefixes] || {}).each_pair do |k, v|
        @uri_to_prefix[v.to_s] = k
      end
      @options[:prefixes] = {}  # Will define actual used when matched

      prefix(:rdf, RDF.to_uri)
      @uri_to_prefix[RDF.to_uri.to_s] = :rdf
      if base_uri || @options[:lang]
        prefix(:xml, RDF::XML)
        @uri_to_prefix[RDF::XML.to_s] = :xml
      end

      if @options[:default_namespace]
        @uri_to_prefix[@options[:default_namespace]] = nil
        prefix(nil, @options[:default_namespace])
      end

      # Process each statement to establish CURIEs and Terms
      @graph.each {|statement| preprocess_statement(statement)}
    end

    ##
    # Turn CURIE into a QNAME
    def get_qname(uri)
      curie = get_curie(uri)
      curie.start_with?(":") ? curie[1..-1] : curie
    end

    # Perform any statement preprocessing required. This is used to perform reference counts and determine required prefixes.
    #
    # For RDF/XML, make sure that all predicates have CURIEs
    # @param [Statement] statement
    def preprocess_statement(statement)
      super

      # Invent a prefix for the predicate, if necessary
      ensure_curie(statement.predicate)
      ensure_curie(statement.object) if statement.predicate == RDF.type
    end

    # Make sure a CURIE is defined
    def ensure_curie(resource)
      if get_curie(resource) == resource.to_s || get_curie(resource).split(':', 2).last =~ /[\.#]/
        uri = resource.to_s
        # No vocabulary found, invent one
        # Add bindings for predicates not already having bindings
        # From RDF/XML Syntax and Processing:
        #   An XML namespace-qualified name (QName) has restrictions on the legal characters such that not all property URIs can be expressed as these names. It is recommended that implementors of RDF serializers, in order to break a URI into a namespace name and a local name, split it after the last XML non-NCName character, ensuring that the first character of the name is a Letter or '_'. If the URI ends in a non-NCName character then throw a "this graph cannot be serialized in RDF/XML" exception or error.
        separation = uri.rindex(%r{[^a-zA-Z_0-9-][a-zA-Z_][a-z0-9A-Z_-]*$})
        return @uri_to_prefix[uri] = nil unless separation
        base_uri = uri.to_s[0..separation]
        suffix = uri.to_s[separation+1..-1]
        @gen_prefix = @gen_prefix ? @gen_prefix.succ : "ns0"
        log_debug {"ensure_curie: generated prefix #{@gen_prefix} for #{base_uri}"}
        @uri_to_prefix[base_uri] = @gen_prefix
        @uri_to_term_or_curie[uri] = "#{@gen_prefix}:#{suffix}"
        prefix(@gen_prefix, base_uri)
        get_curie(resource)
      end
    end
    
    # If base_uri is defined, use it to try to make uri relative
    # @param [#to_s] uri
    # @return [String]
    def relativize(uri)
      uri = expand_curie(uri.to_s)
      base_uri ? uri.sub(base_uri.to_s, "") : uri
    end

    # Undo CURIE
    # @return [RDF::URI]
    def expand_curie(curie)
      pfx, suffix = curie.split(":", 2)
      prefix(pfx) ? prefix(pfx) + suffix : curie
    end
  end
end

require 'rdf/rdfxml/writer/haml_templates'
