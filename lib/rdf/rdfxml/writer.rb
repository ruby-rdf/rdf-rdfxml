require 'nokogiri'  # FIXME: Implement using different modules as in RDF::TriX

module RDF::RDFXML
  ##
  # An RDF/XML serialiser in Ruby
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Writer < RDF::Writer
    format RDF::RDFXML::Format

    VALID_ATTRIBUTES = [:none, :untyped, :typed]

    attr_accessor :graph, :base
    

    ##
    # @param  [IO, File]               output
    # @param  [Hash{Symbol => Object}] options
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      super do
        @graph = RDF::Graph.new
        @stream = nil
        @base = nil
        @force_RDF_about = {}
        @max_depth = options[:max_depth] || 3
        @base = options[:base]
        @lang = options[:lang]
        @attributes = options[:attributes] || :none
        raise "Invalid attribute option '#{@attributes}', should be one of #{VALID_ATTRIBUTES.to_sentence}" unless VALID_ATTRIBUTES.include?(@attributes.to_sym)
        self.reset
      end
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
      @graph << [subject, predicate, object]
    end

    ##
    # Outputs the RDF/XML representation of all stored triples.
    #
    # @return [void]
    # @see    #write_triple
    def write_epilogue
      doc = Nokogiri::XML::Document.new

      puts "\nserialize: graph namespaces: #{@graph.nsbinding.inspect}" if $DEBUG

      preprocess

      predicates = @graph.predicates.uniq
      possible = predicates + @graph.objects.uniq
      namespaces = {}
      required_namespaces = {}
      possible.each do |res|
        next unless res.is_a?(RDF::URI)
        if res.namespace
          add_namespace(res.namespace)
        else
          required_namespaces[res.base] = true
        end
        #puts "possible namespace for #{res}: #{res.namespace || %(<#{res.base}>)}"
      end
      add_namespace(RDF_NS)
      add_namespace(XML_NS) if @base || @lang
      
      # See if there's a default namespace, and favor it when generating element names.
      # Lookup an equivalent prefixed namespace for use in generating attributes
      @default_ns = @graph.namespace("")
      if @default_ns
        add_namespace(@default_ns)
        prefix = @graph.prefix(@default_ns.uri)
        @prefixed_default_ns = @graph.namespace(prefix)
        add_namespace(@prefixed_default_ns) if @prefixed_default_ns
      end
      
      # Add bindings for predicates not already having bindings
      tmp_ns = "ns0"
      required_namespaces.keys.each do |uri|
        puts "create namespace definition for #{uri}" if $DEBUG
        add_namespace(Namespace.new(uri, tmp_ns))
        tmp_ns = tmp_ns.succ
      end

      doc.root = Nokogiri::XML::Element.new("rdf:RDF", doc)
      @namespaces.each_pair do |p, ns|
        if p.to_s.empty?
          doc.root.default_namespace = ns.uri.to_s
        else
          doc.root.add_namespace(p, ns.uri.to_s)
        end
      end
      doc.root["xml:lang"] = @lang if @lang
      doc.root["xml:base"] = @base if @base
      
      # Add statements for each subject
      order_subjects.each do |subject|
        #puts "subj: #{subject.inspect}"
        subject(subject, doc.root)
      end

      doc.write_xml_to(stream, :encoding => "UTF-8", :indent => 2)
    end
    
    protected
    def subject(subject, parent_node)
      node = nil
      
      if !is_done?(subject)
        subject_done(subject)
        properties = @graph.properties(subject)
        prop_list = sort_properties(properties)
        puts "subject: #{subject.to_n3}, props: #{properties.inspect}" if $DEBUG

        rdf_type, *rest = properties.fetch(RDF_TYPE.to_s, [])
        if rdf_type.is_a?(RDF::URI)
          element = get_qname(rdf_type)
          properties[RDF_TYPE.to_s] = rest
          type_ns = rdf_type.namespace rescue nil
          if type_ns && @default_ns && type_ns.uri == @default_ns.uri
            properties[RDF_TYPE.to_s] = rest
            element = rdf_type.short_name
          end
        end
        element ||= "rdf:Description"

        node = Nokogiri::XML::Element.new(element, parent_node.document)
      
        if subject.is_a?(BNode)
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
      qname = prop.to_qname(uri_binding)
      raise RdfException, "No qname generated for <#{prop}>" unless qname

      # See if we can serialize as attribute.
      # * untyped attributes that aren't duplicated where xml:lang == @lang
      # * typed attributes that aren't duplicated if @dt_as_attr is true
      # * rdf:type
      as_attr = false
      as_attr ||= true if [:untyped, :typed].include?(@attributes) && prop == RDF_TYPE

      # Untyped attribute with no lang, or whos lang is the same as the default and RDF_TYPE
      as_attr ||= true if [:untyped, :typed].include?(@attributes) &&
        (object.is_a?(Literal) && object.untyped? && (object.lang.nil? || object.lang == @lang))
      
      as_attr ||= true if [:typed].include?(@attributes) && object.is_a?(Literal) && object.typed?

      as_attr = false unless is_unique
      
      # Can't do as an attr if the qname has no prefix and there is no prefixed version
      if @default_ns && prop.namespace.uri == @default_ns.uri
        if as_attr
          if @prefixed_default_ns
            qname = "#{@prefixed_default_ns.prefix}:#{prop.short_name}"
          else
            as_attr = false
          end
        else
          qname = prop.short_name
        end
      end

      puts "predicate: #{qname}, as_attr: #{as_attr}, object: #{object.inspect}, done: #{is_done?(object)}, sub: #{@subjects.include?(object)}" if $DEBUG
      qname = "rdf:li" if qname.match(/rdf:_\d+/)
      pred_node = Nokogiri::XML::Element.new(qname, node.document)
      
      if object.is_a?(Literal) || is_done?(object) || !@subjects.include?(object)
        # Literals or references to objects that aren't subjects, or that have already been serialized
        
        args = object.xml_args
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
            av = relativize(object) if a == "#{RDF_NS.prefix}:resource"
            puts "  elt attr #{a}=#{av}" if $DEBUG
            pred_node[a] = av.to_s
          end
          puts "  elt #{'xmllit ' if object.is_a?(Literal) && object.xmlliteral?}content=#{args.first}" if $DEBUG && !args.empty?
          if object.is_a?(Literal) && object.xmlliteral?
            pred_node.add_child(Nokogiri::XML::CharacterData.new(args.first, node.document))
          elsif args.first
            pred_node.content = args.first unless args.empty?
          end
        end
      else
        # Check to see if it can be serialized as a collection
        col = @graph.seq(object)
        conformant_list = col.all? {|item| !item.is_a?(Literal)}
        o_props = @graph.properties(object)
        if conformant_list && o_props[RDF_NS.first.to_s]
          # Serialize list as parseType="Collection"
          pred_node["rdf:parseType"] = "Collection"
          col.each do |item|
            # Mark the BNode subject of each item as being complete, so that it is not serialized
            @graph.triples(Triple.new(nil, RDF_NS.first, item)) do |triple, ctx|
              subject_done(triple.subject)
            end
            @force_RDF_about[item] = true
            subject(item, pred_node)
          end
        else
          if @depth < @max_depth
            @depth += 1
            subject(object, pred_node)
            @depth -= 1
          elsif object.is_a?(BNode)
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
      self.base ? uri.sub(/^#{self.base}/, "") : uri
    end

    def preprocess_triple(triple)
      super
      
      # Pre-fetch qnames, to fill namespaces
      get_qname(triple.predicate)
      get_qname(triple.object) if triple.predicate == RDF_TYPE

      @references[triple.predicate] = ref_count(triple.predicate) + 1
    end

    MAX_DEPTH = 10
    INDENT_STRING = " "
    
    def top_classes; [RDFS_NS.Class]; end
    def predicate_order; [RDF_TYPE, RDFS_NS.label, DC_NS.title]; end
    
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
        graph.triples(Triple.new(nil, RDF_TYPE, class_uri)).map {|t| t.subject}.sort.uniq.each do |subject|
          #puts "order_subjects: #{subject.inspect}"
          subjects << subject
          seen[subject] = @top_levels[subject] = true
        end
      end
      
      # Sort subjects by resources over bnodes, ref_counts and the subject URI itself
      recursable = @subjects.keys.
        select {|s| !seen.include?(s)}.
        map {|r| [r.is_a?(BNode) ? 1 : 0, ref_count(r), r]}.
        sort
      
      subjects += recursable.map{|r| r.last}
    end
    
    def preprocess
      @graph.triples.each {|t| preprocess_triple(t)}
    end
    
    def preprocess_triple(triple)
      #puts "preprocess: #{triple.inspect}"
      references = ref_count(triple.object) + 1
      @references[triple.object] = references
      @subjects[triple.subject] = true
    end
    
    # Return the number of times this node has been referenced in the object position
    def ref_count(node)
      @references.fetch(node, 0)
    end

    # Return a QName for the URI, or nil. Adds namespace of QName to defined namespaces
    def get_qname(uri)
      if uri.is_a?(RDF::URI)
        qn = @graph.qname(uri)
        # Local parts with . will mess up serialization
        return false if qn.nil? || qn.index('.')
        
        add_namespace(uri.namespace)
        qn
      end
    end
    
    def add_namespace(ns)
      @namespaces[ns.prefix.to_s] = ns
    end

    # URI -> Namespace bindings (similar to graph) for looking up qnames
    def uri_binding
      @uri_binding ||= @namespaces.values.inject({}) {|hash, ns| hash[ns.uri.to_s] = ns; hash}
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

    # Returns indent string multiplied by the depth
    def indent(modifier = 0)
      INDENT_STRING * (@depth + modifier)
    end
    
    # Write text
    def write(text)
      @stream.write(text)
    end

  end
end