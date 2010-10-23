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
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Writer < RDF::Writer
    format RDF::RDFXML::Format

    VALID_ATTRIBUTES = [:none, :untyped, :typed]

    attr_accessor :graph, :base_uri

    ##
    # Initializes the RDF/XML writer instance.
    #
    # Opitons:
    # max_depth:: Maximum depth for recursively defining resources, defaults to 3
    # base_uri:: Base URI of graph, used to shorting URI references
    # lang:: Output as root xml:lang attribute, and avoid generation _xml:lang_ where possible
    # attributes:: How to use XML attributes when serializing, one of :none, :untyped, :typed. The default is :none.
    # default_namespace:: URI to use as default namespace
    #
    # @param  [IO, File]               output
    # @param  [Hash{Symbol => Object}] options
    #   @option options [Integer]       :max_depth      (nil)
    #   @option options [String, #to_s] :base_uri (nil)
    #   @option options [String, #to_s] :lang   (nil)
    #   @option options [Array]         :attributes   (nil)
    #   @option options [String]        :default_namespace
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      @graph = RDF::Graph.new
      super
    end

    ##
    # @param  [Graph] graph
    # @return [void]
    def insert_graph(graph)
      @graph = graph
    end

    ##
    # @param  [Statement] statement
    # @return [void]
    def insert_statement(statement)
      @graph << statement
    end

    ##
    # Stores the RDF/XML representation of a triple.
    #
    # @param  [RDF::Resource] subject
    # @param  [RDF::URI]      predicate
    # @param  [RDF::Value]    object
    # @return [void]
    # @see    #write_epilogue
    def insert_triple(subject, predicate, object)
      @graph << RDF::Statement.new(subject, predicate, object)
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
      @default_namespace = @options[:default_namespace]
      raise "Invalid attribute option '#{@attributes}', should be one of #{VALID_ATTRIBUTES.to_sentence}" unless VALID_ATTRIBUTES.include?(@attributes.to_sym)
      self.reset

      doc = Nokogiri::XML::Document.new

      add_debug "\nserialize: graph: #{@graph.size}"

      preprocess

      prefix(:rdf, RDF.to_uri)
      prefix(:xml, RDF::XML) if @base_uri || @lang
      
      if @default_namespace
        prefix(:__default__, @default_namespace.respond_to?(:to_uri) ? @default_namespace.to_uri : @default_namespace)
        @default_namespace_prefix = prefixes.invert[@default_namespace]
        add_debug("def_namespace: #{@default_namespace}, prefix: #{@default_namespace_prefix}")
      end
      
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
        if p == :__default__
          doc.root.default_namespace = uri.to_s
        else
          doc.root.add_namespace(p.to_s, uri.to_s)
        end
      end

      doc.write_xml_to(@output, :encoding => "UTF-8", :indent => 2)
    end
    
    protected
    def subject(subject, parent_node)
      node = nil
      
      if !is_done?(subject)
        subject_done(subject)
        properties = @graph.properties(subject)
        prop_list = sort_properties(properties)
        add_debug "subject: #{subject.inspect}, props: #{properties.inspect}"

        rdf_type, *rest = properties.fetch(RDF.type.to_s, [])
        if rdf_type.is_a?(RDF::URI)
          element = get_qname(rdf_type)
          properties[RDF.type.to_s] = rest
          
          # FIXME: different namespace logic
          type_ns = rdf_type.vocab rescue nil
          if type_ns && @default_namespace && type_ns.to_s == @default_namespace.to_s
            properties[RDF.type.to_s] = rest
            element = rdf_type.qname.last
          end
        end
        element ||= "rdf:Description"

        node = Nokogiri::XML::Element.new(element.to_s, parent_node.document)
      
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
      qname = get_qname(prop)
      raise RDF::WriterError, "No qname generated for <#{prop}>" unless qname

      # See if we can serialize as attribute.
      # * untyped attributes that aren't duplicated where xml:lang == @lang
      # * typed attributes that aren't duplicated if @dt_as_attr is true
      # * rdf:type
      as_attr = false
      as_attr ||= true if [:untyped, :typed].include?(@attributes) && prop == RDF.type

      # Untyped attribute with no lang, or whos lang is the same as the default and RDF.type
      add_debug("as_attr? #{@attributes}, plain? #{object.plain?}, lang #{@lang || 'nil'}:#{object.language || 'nil'}") if object.is_a?(RDF::Literal)
      as_attr ||= true if [:untyped, :typed].include?(@attributes) &&
        object.is_a?(RDF::Literal) && (object.plain? || (@lang && object.language.to_s == @lang.to_s))
      
      as_attr ||= true if [:typed].include?(@attributes) && object.is_a?(RDF::Literal) && object.typed?

      as_attr = false unless is_unique
      
      # Can't do as an attr if the qname has no prefix and there is no prefixed version
      if @default_namespace && prop.vocab.to_s == @default_namespace.to_s
        if as_attr
          if @default_namespace_prefix
            qname = "#{@default_namespace_prefix}:#{prop.qname.last}"
          else
            as_attr = false
          end
        else
          qname = prop.qname.last.to_s
        end
      end

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

    def relativize(uri)
      uri = uri.to_s
      self.base_uri ? uri.sub(self.base_uri, "") : uri
    end

    def preprocess_triple(triple)
      super
      
      # Pre-fetch qnames, to fill namespaces
      get_qname(triple.predicate)
      get_qname(triple.object) if triple.predicate == RDF.type

      @references[triple.predicate] = ref_count(triple.predicate) + 1
    end

    MAX_DEPTH = 10
    INDENT_STRING = " "
    
    def top_classes; [RDF::RDFS.Class]; end
    def predicate_order; [RDF.type, RDF::RDFS.label, RDF::DC.title]; end
    
    def is_done?(subject)
      @serialized.include?(subject)
    end
    
    # Mark a subject as done.
    def subject_done(subject)
      @serialized[subject] = true
    end
    
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
    
    def preprocess
      @graph.each {|statement| preprocess_statement(statement)}
    end
    
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

    # Return a QName for the URI, or nil. Adds namespace of QName to defined namespaces
    def get_qname(uri)
      if uri.is_a?(RDF::URI)
        # Duplicate logic from URI#qname to remember namespace assigned
        if uri.qname
          prefix(uri.qname.first, uri.vocab.to_uri)
          add_debug "get_qname(uri.qname): #{uri.qname.join(':')}"
          return uri.qname.join(":") 
        end
        
        # No vocabulary assigned, find one from cache of created namespace URIs
        prefixes.each_pair do |prefix, vocab|
          if uri.to_s.index(vocab.to_s) == 0
            uri.vocab = vocab
            local_name = uri.to_s[(vocab.to_s.length)..-1]
            add_debug "get_qname(ns): #{prefix}:#{local_name}"
            return "#{prefix}:#{local_name}"
          end
        end
        
        # No vocabulary found, invent one
        # Add bindings for predicates not already having bindings
        # From RDF/XML Syntax and Processing:
        #   An XML namespace-qualified name (QName) has restrictions on the legal characters such that not all property URIs can be expressed
        #   as these names. It is recommended that implementors of RDF serializers, in order to break a URI into a namespace name and a local
        #   name, split it after the last XML non-NCName character, ensuring that the first character of the name is a Letter or '_'. If the
        #   URI ends in a non-NCName character then throw a "this graph cannot be serialized in RDF/XML" exception or error.
        separation = uri.to_s.rindex(%r{[^a-zA-Z_0-9-](?=[a-zA-Z_])})
        return nil unless separation
        base_uri = uri.to_s[0..separation]
        local_name = uri.to_s[separation+1..-1]
        @tmp_ns = @tmp_ns ? @tmp_ns.succ : "ns0"
        add_debug "create namespace definition for #{uri}"
        uri.vocab = RDF::Vocabulary(base_uri)
        prefix(@tmp_ns.to_sym, uri.vocab.to_uri)
        add_debug "get_qname(tmp_ns): #{@tmp_ns}:#{local_name}"
        return "#{@tmp_ns}:#{local_name}"
      end
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

    # Take a hash from predicate uris to lists of values.
    # Sort the lists of values.  Return a sorted list of properties.
    def sort_properties(properties)
      properties.keys.each do |k|
        properties[k] = properties[k].sort do |a, b|
          a_li = a.is_a?(RDF::URI) && a.qname && a.qname.last =~ /^_\d+$/ ? a.to_i : a.to_s
          b_li = b.is_a?(RDF::URI) && b.qname && b.qname.last =~ /^_\d+$/ ? b.to_i : b.to_s
          
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

    # Returns indent string multiplied by the depth
    def indent(modifier = 0)
      INDENT_STRING * (@depth + modifier)
    end
  end
end