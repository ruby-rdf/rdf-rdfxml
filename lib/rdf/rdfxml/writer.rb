require 'nokogiri'  # FIXME: Implement using different modules as in RDF::TriX
require 'rdf/rdfxml/patches/graph_properties'

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
  #   RDF::Writer.for(:file_name      => "etc/test.rdf")
  #   RDF::Writer.for(:file_extension => "rdf")
  #   RDF::Writer.for(:content_type   => "application/rdf+xml")
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
  #   RDF::RDFXML::Writer.buffer(:base_uri => "http://example.com/", :prefixes => {
  #       nil => "http://example.com/ns#",
  #       :foaf => "http://xmlns.com/foaf/0.1/"}
  #   ) do |writer|
  #     graph.each_statement do |statement|
  #       writer << statement
  #     end
  #   end
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Writer < RDF::Writer
    format RDF::RDFXML::Format

    VALID_ATTRIBUTES = [:none, :untyped, :typed]

    # @return [Graph] Graph of statements serialized
    attr_accessor :graph
    # @return [URI] Base URI used for relativizing URIs
    attr_accessor :base_uri
    
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
    # @option options [Integer]  :max_depth (3)
    #   Maximum depth for recursively defining resources
    # @option options [#to_s]   :lang   (nil)
    #   Output as root xml:lang attribute, and avoid generation _xml:lang_ where possible
    # @option options [Array]    :attributes   (nil)
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
      super do
        @graph = RDF::Repository.new
        @uri_to_qname = {}
        @uri_to_prefix = {}
        block.call(self) if block_given?
      end
    end

    ##
    # Write whole graph
    #
    # @param  [Graph] graph
    # @return [void]
    def write_graph(graph)
      @graph = graph
    end

    ##
    # Addes a statement to be serialized
    # @param  [RDF::Statement] statement
    # @return [void]
    def write_statement(statement)
      @graph.insert(statement)
    end

    ##
    # Addes a triple to be serialized
    # @param  [RDF::Resource] subject
    # @param  [RDF::URI]      predicate
    # @param  [RDF::Value]    object
    # @return [void]
    # @abstract
    def write_triple(subject, predicate, object)
      @graph.insert(Statement.new(subject, predicate, object))
    end

    ##
    # Outputs the RDF/XML representation of all stored triples.
    #
    # @return [void]
    # @raise [RDF::WriterError] when attempting to write non-conformant graph
    # @see    #write_triple
    def write_epilogue
      @force_RDF_about = {}
      @max_depth = @options[:max_depth] || 3
      @base_uri = @options[:base_uri]
      @lang = @options[:lang]
      @attributes = @options[:attributes] || :none
      @debug = @options[:debug]
      raise RDF::WriterError, "Invalid attribute option '#{@attributes}', should be one of #{VALID_ATTRIBUTES.to_sentence}" unless VALID_ATTRIBUTES.include?(@attributes.to_sym)
      self.reset

      doc = Nokogiri::XML::Document.new

      add_debug {"\nserialize: graph of size #{@graph.size}"}
      add_debug {"options: #{@options.inspect}"}

      preprocess

      prefix(:rdf, RDF.to_uri)
      prefix(:xml, RDF::XML) if base_uri || @lang
      
      add_debug {"\nserialize: graph namespaces: #{prefixes.inspect}"}
      
      doc.root = Nokogiri::XML::Element.new("rdf:RDF", doc)
      doc.root["xml:lang"] = @lang if @lang
      doc.root["xml:base"] = base_uri if base_uri

      if @options[:stylesheet]
        pi = Nokogiri::XML::ProcessingInstruction.new(
          doc, "xml-stylesheet",
          "type=\"text/xsl\" href=\"#{@options[:stylesheet]}\""
        )
        doc.root.add_previous_sibling pi
      end
      
      # Add statements for each subject
      order_subjects.each do |subject|
        #add_debug "{subj: #{subject.inspect}"}
        subject(subject, doc.root)
      end

      prefixes.each_pair do |p, uri|
        if p == nil
          doc.root.default_namespace = uri.to_s
        else
          doc.root.add_namespace(p.to_s, uri.to_s)
        end
      end

      add_debug {"doc:\n #{doc.to_xml(:encoding => "UTF-8", :indent => 2)}"}
      doc.write_xml_to(@output, :encoding => "UTF-8", :indent => 2)
    end
    
    # Return a QName for the URI, or nil. Adds namespace of QName to defined prefixes
    # @param [URI,#to_s] resource
    # @param [Hash<Symbol => Object>] options
    # @option [Boolean] :with_default (false) If a default mapping exists, use it, otherwise if a prefixed mapping exists, use it
    # @return [String, nil] value to use to identify URI
    def get_qname(resource, options = {})
      case resource
      when RDF::Node
        add_debug {"qname(#{resource.inspect}): #{resource}"}
        return resource.to_s
      when RDF::URI
        uri = resource.to_s
      else
        add_debug {"qname(#{resource.inspect}): nil"}
        return nil
      end

      qname = case
      when options[:with_default] && prefix(nil) && uri.index(prefix(nil)) == 0
        # Don't cache
        add_debug {"qname(#{resource.inspect}): #{uri.sub(prefix(nil), '').inspect} (default)"}
        return uri.sub(prefix(nil), '')
      when @uri_to_qname.has_key?(uri)
        add_debug {"qname(#{resource.inspect}): #{@uri_to_qname[uri].inspect} (cached)"}
        return @uri_to_qname[uri]
      when u = @uri_to_prefix.keys.detect {|u| uri.index(u.to_s) == 0 && NC_REGEXP.match(uri[u.to_s.length..-1])}
        # Use a defined prefix
        prefix = @uri_to_prefix[u]
        prefix(prefix, u)  # Define for output
        uri.sub(u.to_s, "#{prefix}:")
      when @options[:standard_prefixes] && vocab = RDF::Vocabulary.detect {|v| uri.index(v.to_uri.to_s) == 0 && NC_REGEXP.match(uri[v.to_uri.to_s.length..-1])}
        prefix = vocab.__name__.to_s.split('::').last.downcase
        @uri_to_prefix[vocab.to_uri.to_s] = prefix
        prefix(prefix, vocab.to_uri) # Define for output
        uri.sub(vocab.to_uri.to_s, "#{prefix}:")
      else
        
        # No vocabulary found, invent one
        # Add bindings for predicates not already having bindings
        # From RDF/XML Syntax and Processing:
        #   An XML namespace-qualified name (QName) has restrictions on the legal characters such that not all
        #   property URIs can be expressed as these names. It is recommended that implementors of RDF serializers,
        #   in order to break a URI into a namespace name and a local name, split it after the last XML non-NCName
        #   character, ensuring that the first character of the name is a Letter or '_'. If the URI ends in a
        #   non-NCName character then throw a "this graph cannot be serialized in RDF/XML" exception or error.
        separation = uri.rindex(%r{[^a-zA-Z_0-9-][a-zA-Z_][a-z0-9A-Z_-]*$})
        return @uri_to_qname[uri] = nil unless separation
        base_uri = uri.to_s[0..separation]
        suffix = uri.to_s[separation+1..-1]
        @gen_prefix = @gen_prefix ? @gen_prefix.succ : "ns0"
        @uri_to_prefix[base_uri] = @gen_prefix
        prefix(@gen_prefix, base_uri)
        "#{@gen_prefix}:#{suffix}"
      end
      
      add_debug {"qname(#{resource.inspect}): #{qname.inspect}"}
      @uri_to_qname[uri] = qname
    rescue ArgumentError => e
      raise RDF::WriterError, "Invalid URI #{uri.inspect}: #{e.message}"
    end
    
    protected
    # If base_uri is defined, use it to try to make uri relative
    # @param [#to_s] uri
    # @return [String]
    def relativize(uri)
      uri = uri.to_s
      base_uri ? uri.sub(base_uri.to_s, "") : uri
    end

    # Defines rdf:type of subjects to be emitted at the beginning of the graph. Defaults to none
    # @return [Array<URI>]
    def top_classes; []; end

    # Defines order of predicates to to emit at begninning of a resource description. Defaults to
    # `\[rdf:type, rdfs:label, dc:title\]`
    # @return [Array<URI>]
    def predicate_order; [RDF.type, RDF::RDFS.label, RDF::DC.title]; end
    
    # Order subjects for output. Override this to output subjects in another order.
    #
    # Uses top_classes
    # @return [Array<Resource>] Ordered list of subjects
    def order_subjects
      seen = {}
      subjects = []
      
      top_classes.each do |class_uri|
        graph.query(:predicate => RDF.type, :object => class_uri).map {|st| st.subject}.sort.uniq.each do |subject|
          #add_debug "{order_subjects: #{subject.inspect}"}
          subjects << subject
          seen[subject] = @top_levels[subject] = true
        end
      end
      
      # Sort subjects by resources over bnodes, ref_counts and the subject URI itself
      recursable = @subjects.keys.
        select {|s| !seen.include?(s)}.
        map {|r| [(r.is_a?(RDF::Node) ? 1 : 0) + ref_count(r), r]}.
        sort_by {|l| l.first }
      
      subjects += recursable.map{|r| r.last}
    end
    
    # Perform any preprocessing of statements required
    def preprocess
      default_namespace = @options[:default_namespace] || prefix(nil)

      # Load defined prefixes
      (@options[:prefixes] || {}).each_pair do |k, v|
        @uri_to_prefix[v.to_s] = k
      end
      @options[:prefixes] = {}  # Will define actual used when matched

      if default_namespace
        add_debug {"preprocess: default_namespace: #{default_namespace}"}
        prefix(nil, default_namespace) 
      end

      @graph.each {|statement| preprocess_statement(statement)}
    end
    
    # Perform any statement preprocessing required. This is used to perform reference counts and determine required
    # prefixes.
    # @param [Statement] statement
    def preprocess_statement(statement)
      #add_debug {"preprocess: #{statement.inspect}"}
      references = ref_count(statement.object) + 1
      @references[statement.object] = references
      @subjects[statement.subject] = true
    end
    
    # Returns indent string multiplied by the depth
    # @param [Integer] modifier Increase depth by specified amount
    # @return [String] A number of spaces, depending on current depth
    def indent(modifier = 0)
      " " * (@depth + modifier)
    end

    def reset
      @depth = 0
      @lists = {}
      prefixes = {}
      @references = {}
      @serialized = {}
      @subjects = {}
      @top_levels = {}
    end

    private
    def subject(subject, parent_node)
      node = nil
      
      raise RDF::WriterError, "Illegal use of subject #{subject.inspect}, not supported in RDF/XML" unless subject.resource?
      
      if !is_done?(subject)
        subject_done(subject)
        properties = @graph.properties(subject)
        add_debug {"subject: #{subject.inspect}, props: #{properties.inspect}"}

        @graph.query(:subject => subject).each do |st|
          raise RDF::WriterError, "Illegal use of predicate #{st.predicate.inspect}, not supported in RDF/XML" unless st.predicate.uri?
        end

        rdf_type, *rest = properties.fetch(RDF.type.to_s, [])
        qname = get_qname(rdf_type, :with_default => true)
        if rdf_type.is_a?(RDF::Node)
          # Must serialize with an element
          qname = rdf_type = nil
        elsif rest.empty?
          properties.delete(RDF.type.to_s)
        else
          properties[RDF.type.to_s] = Array(rest)
        end
        prop_list = order_properties(properties)
        add_debug {"=> property order: #{prop_list.to_sentence}"}

        if qname
          rdf_type = nil
        else
          qname = "rdf:Description"
          prefixes[:rdf] = RDF.to_uri
        end

        node = Nokogiri::XML::Element.new(qname, parent_node.document)
        
        node["rdf:type"] = rdf_type if rdf_type
      
        if subject.is_a?(RDF::Node)
          # Only need nodeID if it's referenced elsewhere
          if ref_count(subject) > (@depth == 0 ? 0 : 1)
            node["rdf:nodeID"] = subject.id
          else
            node.add_child(Nokogiri::XML::Comment.new(node.document, "Serialization for #{subject}")) if RDF::RDFXML::debug?
          end
        else
          node["rdf:about"] = relativize(subject)
        end

        prop_list.each do |prop|
          prop_ref = RDF::URI.intern(prop)
          
          properties[prop].each do |object|
            raise RDF::WriterError, "Illegal use of object #{object.inspect}, not supported in RDF/XML" unless object.resource? || object.literal?

            @depth += 1
            predicate(prop_ref, object, node, properties[prop].length == 1)
            @depth -= 1
          end
        end
      elsif @force_RDF_about.include?(subject)
        add_debug {"subject: #{subject.inspect}, force about"}
        node = Nokogiri::XML::Element.new("rdf:Description", parent_node.document)
        if subject.is_a?(RDF::Node)
          node["rdf:nodeID"] = subject.id
        else
          node["rdf:about"] = relativize(subject)
        end
      end
      @force_RDF_about.delete(subject)

      parent_node.add_child(node) if node
    end
    
    # Output a predicate into the specified node.
    #
    # If _is_unique_ is true, this predicate may be able to be serialized as an attribute
    def predicate(prop, object, node, is_unique)
      as_attr = predicate_as_attribute?(prop, object) && is_unique
      
      qname = get_qname(prop, :with_default => !as_attr)
      raise RDF::WriterError, "No qname generated for <#{prop}>" unless qname

      add_debug do
        "predicate: #{qname}, " +
        "as_attr: #{as_attr}, " +
        "object: #{object.inspect}, " +
        "done: #{is_done?(object)}, " +
        "subject: #{@subjects.include?(object)}"
      end
      #qname = "rdf:li" if qname.match(/rdf:_\d+/)
      pred_node = Nokogiri::XML::Element.new(qname, node.document)
      
      o_props = @graph.properties(object)

      col = RDF::List.new(object, @graph).to_a
      conformant_list = col.all? {|item| !item.literal?} && o_props[RDF.first.to_s]
      args = xml_args(object)
      attrs = args.pop

      # Check to see if it can be serialized as a collection
      if conformant_list
        add_debug {"=> as collection: [#{col.map(&:to_s).join(", ")}]"}
        # Serialize list as parseType="Collection"
        pred_node.add_child(Nokogiri::XML::Comment.new(node.document, "Serialization for #{object}")) if RDF::RDFXML::debug?
        pred_node["rdf:parseType"] = "Collection"
        while o_props[RDF.first.to_s]
          # Object is used only for referencing collection item and next
          subject_done(object)
          item = o_props[RDF.first.to_s].first
          object = o_props[RDF.rest.to_s].first
          o_props = @graph.properties(object)
          add_debug {"=> li first: #{item}, rest: #{object}"}
          @force_RDF_about[item] = true
          subject(item, pred_node)
        end
      elsif as_attr
        # Serialize as attribute
        pred_node.unlink
        pred_node = nil
        node[qname] = object.is_a?(RDF::URI) ? relativize(object) : object.value
        add_debug {"=> as attribute: node[#{qname}]=#{node[qname]}, #{object.class}"}
      elsif object.literal?
        # Serialize as element
        add_debug {"predicate as element: #{attrs.inspect}"}
        attrs.each_pair do |a, av|
          next if a.to_s == "xml:lang" && av.to_s == @lang # Lang already specified, don't repeat
          add_debug {"=> elt attr #{a}=#{av}"}
          pred_node[a] = av.to_s
        end
        add_debug {"=> elt #{'xmllit ' if object.literal? && object.datatype == RDF.XMLLiteral}content=#{args.first}"} if !args.empty?
        if object.datatype == RDF.XMLLiteral
          pred_node.inner_html = args.first.to_s
        elsif args.first
          pred_node.content = args.first
        end
      elsif @depth < @max_depth && !is_done?(object) && @subjects.include?(object)
        add_debug("  as element (recurse)")
        @depth += 1
        subject(object, pred_node)
        @depth -= 1
      elsif object.is_a?(RDF::Node)
        add_debug("=> as element (nodeID)")
        pred_node["rdf:nodeID"] = object.id
      else
        add_debug("=> as element (resource)")
        pred_node["rdf:resource"] = relativize(object)
      end

      node.add_child(pred_node) if pred_node
    end

    # Mark a subject as done.
    def subject_done(subject)
      add_debug {"subject_done: #{subject}"}
      @serialized[subject] = true
    end
    
    # Return the number of times this node has been referenced in the object position
    def ref_count(node)
      @references.fetch(node, 0)
    end

    def is_done?(subject)
      #add_debug {"is_done?(#{subject}): #{@serialized.include?(subject)}"}
      @serialized.include?(subject)
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
    
    # Take a hash from predicate uris to lists of values.
    # Sort the lists of values.  Return a sorted list of properties.
    # @param [Hash{String => Array<Resource>}] properties A hash of Property to Resource mappings
    # @return [Array<String>}] Ordered list of properties. Uses predicate_order.
    def order_properties(properties)
      properties.keys.each do |k|
        properties[k] = properties[k].sort_by(&:to_s)
      end
      
      # Make sorted list of properties
      prop_list = []
      
      predicate_order.each do |prop|
        next unless properties[prop]
        prop_list << prop.to_s
      end
      
      properties.keys.sort.each do |prop|
        next if prop_list.include?(prop.to_s)
        prop_list << prop.to_s
      end
      
      prop_list
    end

    # XML content and arguments for serialization
    #  Encoding.the_null_encoding.xml_args("foo", "en-US") => ["foo", {"xml:lang" => "en-US"}]
    def xml_args(object)
      case object
      when RDF::Literal
        if object.simple?
          [object.value, {}]
        elsif object.has_language?
          [object.value, {"xml:lang" => object.language}]
        elsif object.datatype == RDF.XMLLiteral
          [object.value, {"rdf:parseType" => "Literal"}]
        else
          [object.value, {"rdf:datatype" => object.datatype.to_s}]
        end
      when RDF::Node
        [{"rdf:nodeID" => object.id}]
      when RDF::URI
        [{"rdf:resource" => object.to_s}]
      else
        raise RDF::WriterError, "Attempt to serialize #{object.inspect}, not supported in RDF/XML"
      end
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [String] message
    # @yieldreturn [String] appended to message, to allow for lazy-evaulation of message
    def add_debug(message = "")
      return unless ::RDF::RDFXML.debug? || @debug
      message = message + yield if block_given?
      msg = "#{'  ' * @depth}#{message}"
      STDERR.puts msg if ::RDF::RDFXML.debug?
      @debug << msg.force_encoding("utf-8") if @debug.is_a?(Array)
    end
  end
end