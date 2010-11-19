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
    
    # FIXME: temporary patch until fixed in RDF.rb
    # Allow for nil prefix mapping
    def prefix(name, uri = nil)
      name = name.to_s.empty? ? nil : (name.respond_to?(:to_sym) ? name.to_sym : name.to_s.to_sym)
      uri.nil? ? prefixes[name] : prefixes[name] = (uri.respond_to?(:to_sym) ? uri.to_sym : uri.to_s.to_sym)
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
    # @option options [Integer]  :max_depth (3)
    #   Maximum depth for recursively defining resources
    # @option options [S#to_s]   :lang   (nil)
    #   Output as root xml:lang attribute, and avoid generation _xml:lang_ where possible
    # @option options [Array]    :attributes   (nil)
    #   How to use XML attributes when serializing, one of :none, :untyped, :typed. The default is :none.
    # @option options [Boolean]  :standard_prefixes   (false)
    #   Add standard prefixes to _prefixes_, if necessary.
    # @option options [String]   :default_namespace (nil)
    #   URI to use as default namespace, same as prefix(nil)
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      super do
        @graph = RDF::Graph.new
        @uri_to_qname = {}
        prefix(nil, @options[:default_namespace]) if @options[:default_namespace]
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
      @graph.insert_statement(statement)
    end

    ##
    # Addes a statement to be serialized
    # @param  [RDF::Statement] statement
    # @return [void]
    def write_statement(statement)
      @graph.insert_statement(statement)
    end

    ##
    # Addes a triple to be serialized
    # @param  [RDF::Resource] subject
    # @param  [RDF::URI]      predicate
    # @param  [RDF::Value]    object
    # @return [void]
    # @raise  [NotImplementedError] unless implemented in subclass
    # @abstract
    def write_triple(subject, predicate, object)
      @graph.insert_statement(Statement.new(subject, predicate, object))
    end

    ##
    # Outputs the RDF/XML representation of all stored triples.
    #
    # @return [void]
    # @see    #write_triple
    def write_epilogue
      @base_uri = nil
      @force_RDF_about = {}
      @max_depth = @options[:max_depth] || 3
      @base_uri = @options[:base_uri]
      @lang = @options[:lang]
      @attributes = @options[:attributes] || :none
      @debug = @options[:debug]
      raise "Invalid attribute option '#{@attributes}', should be one of #{VALID_ATTRIBUTES.to_sentence}" unless VALID_ATTRIBUTES.include?(@attributes.to_sym)
      self.reset

      doc = Nokogiri::XML::Document.new

      add_debug "\nserialize: graph: #{@graph.size}"

      preprocess

      prefix(:rdf, RDF.to_uri)
      prefix(:xml, RDF::XML) if @base_uri || @lang
      
      add_debug "\nserialize: graph namespaces: #{prefixes.inspect}"
      
      doc.root = Nokogiri::XML::Element.new("rdf:RDF", doc)
      doc.root["xml:lang"] = @lang if @lang
      doc.root["xml:base"] = @base_uri if @base_uri
      
      # Add statements for each subject
      order_subjects.each do |subject|
        #add_debug "subj: #{subject.inspect}"
        subject(subject, doc.root)
      end

      prefixes.each_pair do |p, uri|
        if p == nil
          doc.root.default_namespace = uri.to_s
        else
          doc.root.add_namespace(p.to_s, uri.to_s)
        end
      end

      doc.write_xml_to(@output, :encoding => "UTF-8", :indent => 2)
    end
    
    # Return a QName for the URI, or nil. Adds namespace of QName to defined prefixes
    # @param [URI,#to_s] uri
    # @return [Array<Symbol,Symbol>, nil] Prefix, Suffix pair or nil, if none found
    def get_qname(uri)
      uri = RDF::URI.intern(uri.to_s) unless uri.is_a?(URI)

      unless @uri_to_qname.has_key?(uri)
        # Find in defined prefixes
        prefixes.each_pair do |prefix, vocab|
          if uri.to_s.index(vocab.to_s) == 0
            local_name = uri.to_s[(vocab.to_s.length)..-1]
            add_debug "get_qname(ns): #{prefix}:#{local_name}"
            return @uri_to_qname[uri] = [prefix, local_name.to_sym]
          end
        end
        
        # Use a default vocabulary
        if @options[:standard_prefixes] && vocab = RDF::Vocabulary.detect {|v| uri.to_s.index(v.to_uri.to_s) == 0}
          prefix = vocab.__name__.to_s.split('::').last.downcase
          prefixes[prefix.to_sym] = vocab.to_uri
          suffix = uri.to_s[vocab.to_uri.to_s.size..-1]
          return @uri_to_qname[uri] = [prefix.to_sym, suffix.empty? ? nil : suffix.to_sym] if prefix && suffix
        end
        
        # No vocabulary found, invent one
        # Add bindings for predicates not already having bindings
        # From RDF/XML Syntax and Processing:
        #   An XML namespace-qualified name (QName) has restrictions on the legal characters such that not all property URIs can be expressed
        #   as these names. It is recommended that implementors of RDF serializers, in order to break a URI into a namespace name and a local
        #   name, split it after the last XML non-NCName character, ensuring that the first character of the name is a Letter or '_'. If the
        #   URI ends in a non-NCName character then throw a "this graph cannot be serialized in RDF/XML" exception or error.
        separation = uri.to_s.rindex(%r{[^a-zA-Z_0-9-](?=[a-zA-Z_])})
        return @uri_to_qname[uri] = nil unless separation
        base_uri = uri.to_s[0..separation]
        suffix = uri.to_s[separation+1..-1]
        @gen_prefix = @gen_prefix ? @gen_prefix.succ : "ns0"
        add_debug "create prefix definition for #{uri}"
        prefix(@gen_prefix, base_uri)
        add_debug "get_qname(tmp_ns): #{@gen_prefix}:#{suffix}"
        return @uri_to_qname[uri] = [@gen_prefix.to_sym, suffix.to_sym]
      end
      
      @uri_to_qname[uri]
    rescue Addressable::URI::InvalidURIError
       @uri_to_qname[uri] = nil
    end
    
    protected
    # If @base_uri is defined, use it to try to make uri relative
    # @param [#to_s] uri
    # @return [String]
    def relativize(uri)
      uri = uri.to_s
      @base_uri ? uri.sub(@base_uri.to_s, "") : uri
    end

    # Defines rdf:type of subjects to be emitted at the beginning of the graph. Defaults to rdfs:Class
    # @return [Array<URI>]
    def top_classes; [RDF::RDFS.Class]; end

    # Defines order of predicates to to emit at begninning of a resource description. Defaults to
    # [rdf:type, rdfs:label, dc:title]
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
          #add_debug "order_subjects: #{subject.inspect}"
          subjects << subject
          seen[subject] = @top_levels[subject] = true
        end
      end
      
      # Sort subjects by resources over bnodes, ref_counts and the subject URI itself
      recursable = @subjects.keys.
        select {|s| !seen.include?(s)}.
        map {|r| [r.is_a?(RDF::Node) ? 1 : 0, ref_count(r), r]}.
        sort
      
      subjects += recursable.map{|r| r.last}
    end
    
    # Mark a subject as done.
    def subject_done(subject)
      @serialized[subject] = true
    end
    
    # Perform any preprocessing of statements required
    def preprocess
      @graph.each {|statement| preprocess_statement(statement)}
    end
    
    # Perform any statement preprocessing required. This is used to perform reference counts and determine required
    # prefixes.
    # @param [Statement] statement
    def preprocess_statement(statement)
      #add_debug "preprocess: #{statement.inspect}"
      references = ref_count(statement.object) + 1
      @references[statement.object] = references
      @subjects[statement.subject] = true
    end
    
    # Return the number of times this node has been referenced in the object position
    def ref_count(node)
      @references.fetch(node, 0)
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
      
      if !is_done?(subject)
        subject_done(subject)
        properties = @graph.properties(subject)
        prop_list = sort_properties(properties)
        add_debug "subject: #{subject.inspect}, props: #{properties.inspect}"

        rdf_type, *rest = properties.fetch(RDF.type.to_s, [])
        qname = get_qname_string(rdf_type, :with_default => true)
        if qname
          properties[RDF.type.to_s] = rest
        else
          qname = "rdf:Description"
          prefixes[:rdf] = RDF.to_uri
        end

        node = Nokogiri::XML::Element.new(qname, parent_node.document)
      
        if subject.is_a?(RDF::Node)
          # Only need nodeID if it's referenced elsewhere
          node["rdf:nodeID"] = subject.to_s if ref_count(subject) > (@depth == 0 ? 0 : 1)
        else
          node["rdf:about"] = relativize(subject)
        end

        prop_list.each do |prop|
          prop_ref = RDF::URI.intern(prop)
          
          properties[prop].each do |object|
            @depth += 1
            predicate(prop_ref, object, node, properties[prop].length == 1)
            @depth -= 1
          end
        end
      elsif @force_RDF_about.include?(subject)
        add_debug "subject: #{subject.inspect}, force about"
        node = Nokogiri::XML::Element.new("rdf:Description", parent_node.document)
        node["rdf:about"] = relativize(subject)
        @force_RDF_about.delete(subject)
      end

      parent_node.add_child(node) if node
    end
    
    # Output a predicate into the specified node.
    #
    # If _is_unique_ is true, this predicate may be able to be serialized as an attribute
    def predicate(prop, object, node, is_unique)
      # See if we can serialize as attribute.
      # * untyped attributes that aren't duplicated where xml:lang == @lang
      # * typed attributes that aren't duplicated if @dt_as_attr is true
      # * rdf:type
      as_attr = false
      as_attr = true if [:untyped, :typed].include?(@attributes) && prop == RDF.type

      # Untyped attribute with no lang, or whos lang is the same as the default and RDF.type
      add_debug("as_attr? #{@attributes}, plain? #{object.plain?}, lang #{@lang || 'nil'}:#{object.language || 'nil'}") if object.is_a?(RDF::Literal)
      as_attr ||= true if [:untyped, :typed].include?(@attributes) &&
        object.is_a?(RDF::Literal) && (object.plain? || (@lang && object.language.to_s == @lang.to_s))
      
      as_attr ||= true if [:typed].include?(@attributes) && object.is_a?(RDF::Literal) && object.typed?

      as_attr = false unless is_unique

      qname = get_qname_string(prop, :with_default => !as_attr)
      raise RDF::WriterError, "No qname generated for <#{prop}>" unless qname

      # Can't do as an attr if the qname has no prefix and there is no prefixed version
      as_attr = false if as_attr && qname !~ /:/

      add_debug "predicate: #{qname}, as_attr: #{as_attr}, object: #{object.inspect}, done: #{is_done?(object)}, sub: #{@subjects.include?(object)}"
      qname = "rdf:li" if qname.match(/rdf:_\d+/)
      pred_node = Nokogiri::XML::Element.new(qname, node.document)
      
      if object.is_a?(RDF::Literal) || is_done?(object) || !@subjects.include?(object)
        # Literals or references to objects that aren't subjects, or that have already been serialized
        
        args = xml_args(object)
        add_debug "predicate: args=#{args.inspect}"
        attrs = args.pop
        
        if as_attr
          # Serialize as attribute
          pred_node.unlink
          pred_node = nil
          node[qname] = object.is_a?(RDF::URI) ? relativize(object) : object.value
          add_debug("node[#{qname}]=#{node[qname]}, #{object.class}")
        else
          # Serialize as element
          add_debug("serialize as element: #{attrs.inspect}")
          attrs.each_pair do |a, av|
            next if a.to_s == "xml:lang" && av.to_s == @lang # Lang already specified, don't repeat
            av = relativize(object) if a == "rdf:resource"
            add_debug "  elt attr #{a}=#{av}"
            pred_node[a] = av.to_s
          end
          add_debug "  elt #{'xmllit ' if object.is_a?(RDF::Literal) && object.datatype == RDF.XMLLiteral}content=#{args.first}" if !args.empty?
          if object.is_a?(RDF::Literal) && object.datatype == RDF.XMLLiteral
            pred_node.add_child(Nokogiri::XML::CharacterData.new(args.first, node.document))
          elsif args.first
            pred_node.content = args.first unless args.empty?
          end
        end
      else
        require 'rdf/rdfxml/patches/seq' unless RDF::Graph.respond_to?(:seq)
        
        # Check to see if it can be serialized as a collection
        col = @graph.seq(object)
        conformant_list = col.all? {|item| !item.is_a?(RDF::Literal)}
        o_props = @graph.properties(object)
        if conformant_list && o_props[RDF.first.to_s]
          # Serialize list as parseType="Collection"
          pred_node["rdf:parseType"] = "Collection"
          col.each do |item|
            # Mark the BNode subject of each item as being complete, so that it is not serialized
            @graph.query(:predicate => RDF.first, :object => item) do |statement|
              subject_done(statement.subject)
            end
            @force_RDF_about[item] = true
            subject(item, pred_node)
          end
        else
          if @depth < @max_depth
            @depth += 1
            subject(object, pred_node)
            @depth -= 1
          elsif object.is_a?(RDF::Node)
            pred_node["rdf:nodeID"] = object.id
          else
            pred_node["rdf:resource"] = relativize(object)
          end
        end
      end
      node.add_child(pred_node) if pred_node
    end

    def is_done?(subject)
      @serialized.include?(subject)
    end
    
    
    # Take a hash from predicate uris to lists of values.
    # Sort the lists of values.  Return a sorted list of properties.
    # @param [Hash{String => Array<Resource>}] properties A hash of Property to Resource mappings
    # @return [Array<String>}] Ordered list of properties. Uses predicate_order.
    def sort_properties(properties)
      properties.keys.each do |k|
        properties[k] = properties[k].sort do |a, b|
          a_li = a.is_a?(RDF::URI) && get_qname(a) && get_qname(a).last.to_s =~ /^_\d+$/ ? a.to_i : a.to_s
          b_li = b.is_a?(RDF::URI) && get_qname(b) && get_qname(b).last.to_s =~ /^_\d+$/ ? b.to_i : b.to_s
          
          a_li <=> b_li
        end
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
      
      add_debug "sort_properties: #{prop_list.to_sentence}"
      prop_list
    end

    # XML content and arguments for serialization
    #  Encoding.the_null_encoding.xml_args("foo", "en-US") => ["foo", {"xml:lang" => "en-US"}]
    def xml_args(object)
      case object
      when RDF::Literal
        if object.plain?
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
      end
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [String] message::
    def add_debug(message)
      @debug << message if @debug.is_a?(Array)
    end

    # Return string representation of QName pair
    #
    # @option [Boolean] :with_default (false) If a default mapping exists, use it, otherwise if a prefixed mapping exists, use it
    def get_qname_string(uri, options = {})
      if qname = get_qname(uri)
        if options[:with_default]
          qname[0] = nil if !qname.first.nil? && prefix(qname.first).to_s == prefix(nil).to_s
        elsif qname.first.nil?
          prefix = nil
          prefixes.each_pair {|k, v| prefix = k if !k.nil? && v.to_s == prefix(nil).to_s}
          qname[0] = prefix if prefix
        end
        qname.first == nil ? qname.last.to_s : qname.map(&:to_s).join(":")
      end
    end
  end
end