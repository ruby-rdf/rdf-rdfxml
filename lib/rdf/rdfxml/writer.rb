require 'nokogiri'  # FIXME: Implement using different modules as in RDF::TriX
require 'rdf/rdfxml/patches/qname_hacks'
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
  #   RDF::Writer.for(:rdf)         #=> RDF::TriX::Writer
  #   RDF::Writer.for("etc/test.rdf")
  #   RDF::Writer.for(:file_name      => "etc/test.rdf")
  #   RDF::Writer.for(:file_extension => "rdf")
  #   RDF::Writer.for(:content_type   => "application/rdf+xml")
  #
  # @example Serializing RDF graph into an RDF/XML file
  #   RDF::RDFXML::Write.open("etc/test.rdf") do |writer|
  #     writer.write_graph(graph)
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
    #
    # @param  [IO, File]               output
    # @param  [Hash{Symbol => Object}] options
    #   @option options [Integer]       :max_depth      (nil)
    #   @option options [String, #to_s] :base_uri (nil)
    #   @option options [String, #to_s] :lang   (nil)
    #   @option options [Arrat]         :attributes   (nil)
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      @graph = RDF::Graph.new
      super
    end

    ##
    # @param  [Graph] graph
    # @return [void]
    def write_graph(graph)
      @graph = graph
    end

    ##
    # @param  [Statement] statement
    # @return [void]
    def write_statement(statement)
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
    def write_triple(subject, predicate, object)
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
      raise "Invalid attribute option '#{@attributes}', should be one of #{VALID_ATTRIBUTES.to_sentence}" unless VALID_ATTRIBUTES.include?(@attributes.to_sym)
      self.reset

      doc = Nokogiri::XML::Document.new

      puts "\nserialize: graph namespaces: #{@namespaces.inspect}" if $DEBUG
      puts "\nserialize: graph: #{@graph.size}" if $DEBUG

      preprocess

      predicates = @graph.predicates.uniq
      puts "\nserialize: predicates #{predicates.inspect}" if $DEBUG
      possible = predicates + @graph.objects.uniq
      namespaces = {}
      required_namespaces = {}
      possible.each do |res|
        get_qname(res)
      end
      add_namespace(:rdf, RDF_NS)
      add_namespace(:xml, RDF::XML) if @base_uri || @lang
      
      doc.root = Nokogiri::XML::Element.new("rdf:RDF", doc)
      @namespaces.each_pair do |p, uri|
        if p.to_s.empty?
          doc.root.default_namespace = uri.to_s
        else
          doc.root.add_namespace(p.to_s, uri.to_s)
        end
      end
      doc.root["xml:lang"] = @lang if @lang
      doc.root["xml:base"] = @base_uri if @base_uri
      
      # Add statements for each subject
      order_subjects.each do |subject|
        #puts "subj: #{subject.inspect}"
        subject(subject, doc.root)
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
        puts "subject: #{subject.to_n3}, props: #{properties.inspect}" if $DEBUG

        rdf_type, *rest = properties.fetch(RDF.type.to_s, [])
        if rdf_type.is_a?(RDF::URI)
          element = get_qname(rdf_type)
          properties[RDF.type.to_s] = rest
          
          # FIXME: different namespace logic
          type_ns = rdf_type.vocab rescue nil
          if type_ns && @default_ns && type_ns.to_s == @default_ns.to_s
            properties[RDF.type.to_s] = rest
            element = rdf_type.qname.last
          end
        end
        element ||= "rdf:Description"

        node = Nokogiri::XML::Element.new(element, parent_node.document)
      
        if subject.is_a?(RDF::Node)
          # Only need nodeID if it's referenced elsewhere
          node["rdf:nodeID"] = subject.to_s if ref_count(subject) > (@depth == 0 ? 0 : 1)
        else
          node["rdf:about"] = relativize(subject)
        end

        prop_list.each do |prop|
          prop_ref = RDF::URI.new(prop)
          
          properties[prop].each do |object|
            @depth += 1
            predicate(prop_ref, object, node, properties[prop].length == 1)
            @depth -= 1
          end
        end
      elsif @force_RDF_about.include?(subject)
        puts "subject: #{subject.to_n3}, force about" if $DEBUG
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
      raise RdfException, "No qname generated for <#{prop}>" unless qname

      # See if we can serialize as attribute.
      # * untyped attributes that aren't duplicated where xml:lang == @lang
      # * typed attributes that aren't duplicated if @dt_as_attr is true
      # * rdf:type
      as_attr = false
      as_attr ||= true if [:untyped, :typed].include?(@attributes) && prop == RDF.type

      # Untyped attribute with no lang, or whos lang is the same as the default and RDF.type
      as_attr ||= true if [:untyped, :typed].include?(@attributes) &&
        (object.is_a?(RDF::Literal) && object.plain? && (!object.has_language? || object.language == @lang))
      
      as_attr ||= true if [:typed].include?(@attributes) && object.is_a?(RDF::Literal) && object.typed?

      as_attr = false unless is_unique
      
      # FIXME: different namespace logic
      # Can't do as an attr if the qname has no prefix and there is no prefixed version
      if @default_ns && prop.vocab.to_s == @default_ns.to_s
        if as_attr
          if @prefixed_default_ns
            qname = "#{@prefixed_default_ns.prefix}:#{prop.qname.last}"
          else
            as_attr = false
          end
        else
          qname = prop.qname.last
        end
      end

      puts "predicate: #{qname}, as_attr: #{as_attr}, object: #{object.inspect}, done: #{is_done?(object)}, sub: #{@subjects.include?(object)}" if $DEBUG
      qname = "rdf:li" if qname.match(/rdf:_\d+/)
      pred_node = Nokogiri::XML::Element.new(qname, node.document)
      
      if object.is_a?(RDF::Literal) || is_done?(object) || !@subjects.include?(object)
        # Literals or references to objects that aren't subjects, or that have already been serialized
        
        args = xml_args(object)
        puts "predicate: args=#{args.inspect}" if $DEBUG
        attrs = args.pop
        
        if as_attr
          # Serialize as attribute
          pred_node.unlink
          pred_node = nil
          node[qname] = object.is_a?(RDF::URI) ? relativize(object) : object.to_s
        else
          # Serialize as element
          attrs.each_pair do |a, av|
            next if a == "xml:lang" && av == @lang # Lang already specified, don't repeat
            av = relativize(object) if a == "#{RDF.prefix}:resource"
            puts "  elt attr #{a}=#{av}" if $DEBUG
            pred_node[a] = av.to_s
          end
          puts "  elt #{'xmllit ' if object.is_a?(RDF::Literal) && object.xmlliteral?}content=#{args.first}" if $DEBUG && !args.empty?
          if object.is_a?(RDF::Literal) && object.datatype == XML_LITERAL
            pred_node.add_child(Nokogiri::XML::CharacterData.new(args.first, node.document))
          elsif args.first
            pred_node.content = args.first unless args.empty?
          end
        end
      else
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
            pred_node["rdf:nodeID"] = object.identifier
          else
            pred_node["rdf:resource"] = relativize(object)
          end
        end
      end
      node.add_child(pred_node) if pred_node
    end

    def relativize(uri)
      uri = uri.to_s
      self.base_uri ? uri.sub(/^#{self.base_uri}/, "") : uri
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
          #puts "order_subjects: #{subject.inspect}"
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
      #puts "preprocess: #{statement.inspect}"
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
          add_namespace(uri.qname.first, uri.vocab)
          return uri.qname.join(":") 
        end
        
        # No vocabulary assigned, find one from cache of created namespace URIs
        @namespaces.each_pair do |prefix, vocab|
          if uri.to_s.index(vocab.to_s) == 0
            uri.vocab = vocab
            local_name = uri.to_s[(vocab.to_s.length)..-1]
            return "#{prefix}:#{local_name}"
          end
        end
        
        # No vocabulary found, invent one
        # Add bindings for predicates not already having bindings
        # short_name of URI for creating QNames.
        #   "#{base_uri]{#short_name}}" == uri
        local_name = uri.fragment
        local_name ||= begin
          path = uri.path.split("/")
          unless path &&
              path.length > 1 &&
              path.last.class == String &&
              path.last.length > 0 &&
              path.last.index("/") != 0
            return false
          end
          path.last
        end
        base_uri = uri.to_s[0..-(local_name.length + 1)]
        @tmp_ns = @tmp_ns ? @tmp_ns.succ : "ns0"
        puts "create namespace definition for #{uri}" if $DEBUG
        uri.vocab = RDF::Vocabulary.new(base_uri)
        add_namespace(@tmp_ns.to_sym, uri.vocab)
        return @qname_cache[uri.to_s] =  "#{@tmp_ns}:#{local_name}"
      end
    end
    
    def add_namespace(prefix, ns)
      @namespaces[prefix.to_sym] = ns.to_s
    end

    def reset
      @depth = 0
      @lists = {}
      @namespaces = {}
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
          a_li = a.is_a?(RDF::URI) && a.short_name =~ /^_\d+$/ ? a.to_i : a.to_s
          b_li = b.is_a?(RDF::URI) && b.short_name =~ /^_\d+$/ ? b.to_i : b.to_s
          
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
      
      puts "sort_properties: #{prop_list.to_sentence}" if $DEBUG
      prop_list
    end

    # XML content and arguments for serialization
    #  Encoding.the_null_encoding.xml_args("foo", "en-US") => ["foo", {"xml:lang" => "en-US"}]
    def xml_args(literal)
      if literal.plain?
        [literal.value, {"xml:lang" => "en-US"}]
      elsif literal.datatype == XML_LITERAL
        [literal.value, {"rdf:parseType" => "Literal"}]
      else
        [literal.value, {"rdf:datatype" => literal.datatype.to_s}]
      end
    end
    
    # Returns indent string multiplied by the depth
    def indent(modifier = 0)
      INDENT_STRING * (@depth + modifier)
    end
  end
end