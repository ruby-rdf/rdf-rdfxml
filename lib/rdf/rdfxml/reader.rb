require 'nokogiri'  # FIXME: Implement using different modules as in RDF::TriX

module RDF::RDFXML
  ##
  # An RDF/XML parser in Ruby
  #
  # Based on RDF/XML Syntax Specification: http://www.w3.org/TR/REC-rdf-syntax/
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Reader < RDF::Reader
    format Format

    CORE_SYNTAX_TERMS = %w(RDF ID about parseType resource nodeID datatype).map {|n| "http://www.w3.org/1999/02/22-rdf-syntax-ns##{n}"}
    OLD_TERMS = %w(aboutEach aboutEachPrefix bagID).map {|n| "http://www.w3.org/1999/02/22-rdf-syntax-ns##{n}"}

    # The Recursive Baggage
    class EvaluationContext # :nodoc:
      attr_reader :base
      attr :subject, true
      attr :uri_mappings, true
      attr :language, true
      attr :graph, true
      attr :li_counter, true

      def initialize(base, element, graph, &cb)
        # Initialize the evaluation context, [5.1]
        self.base = RDF::URI.intern(base)
        @uri_mappings = {}
        @language = nil
        @graph = graph
        @li_counter = 0

        extract_from_element(element, &cb) if element
      end
      
      # Clone existing evaluation context adding information from element
      def clone(element, options = {}, &cb)
        new_ec = EvaluationContext.new(@base, nil, @graph)
        new_ec.uri_mappings = self.uri_mappings.clone
        new_ec.language = self.language

        new_ec.extract_from_element(element, &cb) if element
        
        options.each_pair {|k, v| new_ec.send("#{k}=", v)}
        new_ec
      end
      
      # Extract Evaluation Context from an element by looking at ancestors recurively
      def extract_from_ancestors(el, &cb)
        ancestors = el.ancestors
        while ancestors.length > 0
          a = ancestors.pop
          next unless a.element?
          extract_from_element(a, &cb)
        end
        extract_from_element(el, &cb)
      end

      # Extract Evaluation Context from an element
      def extract_from_element(el, &cb)
        b = el.attribute_with_ns("base", RDF::XML.to_s)
        b = nil if b.respond_to?(:null?) && b.null? # to ensure FFI Pointer compatibility
        
        lang = el.attribute_with_ns("lang", RDF::XML.to_s)
        lang = nil if lang.respond_to?(:null?) && lang.null? # to make FFI Pointer compatibility
        
        self.base = self.base.join(b) if b
        self.language = lang if lang
        self.uri_mappings.merge!(extract_mappings(el, &cb))
      end
      
      # Extract the XMLNS mappings from an element
      def extract_mappings(element, &cb)
        mappings = {}

        # look for xmlns
        element.namespaces.each do |attr_name,attr_value|
          abbr, prefix = attr_name.to_s.split(":")
          if abbr == "xmlns"
            attr_value = self.base.to_s + attr_value if attr_value.match(/^\#/)
            mappings[prefix] = attr_value
            cb.call(prefix, attr_value) if block_given?
          end
        end
        mappings
      end
      
      # Produce the next list entry for this context
      def li_next
        @li_counter += 1
        predicate = RDF["_#{@li_counter}"]
      end

      # Set XML base. Ignore any fragment
      def base=(b)
        base = Addressable::URI.parse(b)
        base.fragment = nil
        @base = RDF::URI.intern(base)
      end

      def inspect
        v = %w(base subject language).map {|a| "#{a}='#{self.send(a).nil? ? 'nil' : self.send(a)}'"}
        v << "uri_mappings[#{uri_mappings.keys.length}]"
        v.join(",")
      end
    end

    ##
    # Initializes the RDF/XML reader instance.
    #
    # @param  [Nokogiri::XML::Document, IO, File, String] input
    #   the input stream to read
    # @param  [Hash{Symbol => Object}] options
    #   any additional options
    # @option options [Encoding] :encoding     (Encoding::UTF_8)
    #   the encoding of the input stream (Ruby 1.9+)
    # @option options [Boolean]  :validate     (false)
    #   whether to validate the parsed statements and values
    # @option options [Boolean]  :canonicalize (false)
    #   whether to canonicalize parsed literals
    # @option options [Boolean]  :intern       (true)
    #   whether to intern all parsed URIs
    # @option options [Hash]     :prefixes     (Hash.new)
    #   the prefix mappings to use (not supported by all readers)
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when resolving relative URIs
    # @option options [Array] :debug
    #   Array to place debug messages
    # @return [reader]
    # @yield  [reader] `self`
    # @yieldparam  [RDF::Reader] reader
    # @yieldreturn [void] ignored
    # @raise [Error]:: Raises RDF::ReaderError if _validate_
    def initialize(input = $stdin, options = {}, &block)
      super do
        @debug = options[:debug]
        @base_uri = uri(options[:base_uri]) if options[:base_uri]
            
        @doc = case input
        when Nokogiri::XML::Document then input
        else Nokogiri::XML.parse(input, @base_uri.to_s)
        end
        
        raise RDF::ReaderError, "Synax errors:\n#{@doc.errors}" if !@doc.errors.empty? && validate?
        raise RDF::ReaderError, "Empty document" if (@doc.nil? || @doc.root.nil?) && validate?

        block.call(self) if block_given?
      end
    end

    # No need to rewind, as parsing is done in initialize
    def rewind; end
    
    # Document closed when read in initialize
    def close; end
    
    ##
    # Iterates the given block for each RDF statement in the input.
    #
    # @yield  [statement]
    # @yieldparam [RDF::Statement] statement
    # @return [void]
    def each_statement(&block)
      # Block called from add_statement
      @callback = block

      root = @doc.root

      add_debug(root, "base_uri: #{@base_uri || 'nil'}")
      
      rdf_nodes = root.xpath("//rdf:RDF", "rdf" => RDF.to_uri.to_s)
      if rdf_nodes.length == 0
        # If none found, root element may be processed as an RDF Node

        ec = EvaluationContext.new(@base_uri, root, @graph) do |prefix, value|
          prefix(prefix, value)
        end
        
        nodeElement(root, ec)
      else
        rdf_nodes.each do |node|
          # XXX Skip this element if it's contained within another rdf:RDF element

          # Extract base, lang and namespaces from parents to create proper evaluation context
          ec = EvaluationContext.new(@base_uri, nil, @graph) do |prefix, value|
            prefix(prefix, value)
          end
          ec.extract_from_ancestors(node)
          node.children.each {|el|
            next unless el.elem?
            new_ec = ec.clone(el) do |prefix, value|
              prefix(prefix, value)
            end
            nodeElement(el, new_ec)
          }
        end
      end
    end

    ##
    # Iterates the given block for each RDF triple in the input.
    #
    # @yield  [subject, predicate, object]
    # @yieldparam [RDF::Resource] subject
    # @yieldparam [RDF::URI]      predicate
    # @yieldparam [RDF::Value]    object
    # @return [void]
    def each_triple(&block)
      each_statement do |statement|
        block.call(*statement.to_triple)
      end
    end
    
    private

    # Keep track of allocated BNodes
    def bnode(value = nil)
      @bnode_cache ||= {}
      @bnode_cache[value.to_s] ||= RDF::Node.new(value)
    end
    
    # Figure out the document path, if it is a Nokogiri::XML::Element or Attribute
    def node_path(node)
      case node
      when Nokogiri::XML::Node then node.display_path
      else node.to_s
      end
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [XML Node, any] node:: XML Node or string for showing context
    # @param [String] message::
    def add_debug(node, message)
      puts "#{node_path(node)}: #{message}" if ::RDF::RDFXML::debug?
      @debug << "#{node_path(node)}: #{message}" if @debug.is_a?(Array)
    end

    # add a statement, object can be literal or URI or bnode
    #
    # @param [Nokogiri::XML::Node, any] node:: XML Node or string for showing context
    # @param [URI, BNode] subject:: the subject of the statement
    # @param [URI] predicate:: the predicate of the statement
    # @param [URI, BNode, Literal] object:: the object of the statement
    # @return [Statement]:: Added statement
    # @raise [RDF::ReaderError]:: Checks parameter types and raises if they are incorrect if validating.
    def add_triple(node, subject, predicate, object)
      statement = RDF::Statement.new(subject, predicate, object)
      add_debug(node, "statement: #{statement}")
      @callback.call(statement)
    end

    # XML nodeElement production
    #
    # @param [XML Element] el:: XMl Element to parse
    # @param [EvaluationContext] ec:: Evaluation context
    # @return [RDF::URI] subject:: The subject found for the node
    # @raise [RDF::ReaderError]:: Raises Exception if validating
    def nodeElement(el, ec)
      # subject
      subject = ec.subject || parse_subject(el, ec)
      
      add_debug(el, "nodeElement, ec: #{ec.inspect}")
      add_debug(el, "nodeElement, el: #{el.uri}")
      add_debug(el, "nodeElement, subject: #{subject.nil? ? 'nil' : subject.to_s}")

      unless el.uri.to_s == RDF.Description.to_s
        add_triple(el, subject, RDF.type, el.uri)
      end

      # produce triples for attributes
      el.attribute_nodes.each do |attr|
        add_debug(el, "propertyAttr: #{attr.uri}='#{attr.value}'")
        if attr.uri.to_s == RDF.type.to_s
          # If there is an attribute a in propertyAttr with a.URI == rdf:type
          # then u:=uri(identifier:=resolve(a.string-value))
          # and the following triple is added to the graph:
          u = ec.base.join(attr.value)
          add_triple(attr, subject, RDF.type, u)
        elsif is_propertyAttr?(attr)
          # Attributes not RDF.type
          predicate = attr.uri
          lit = RDF::Literal.new(attr.value, :language => ec.language, :validate => validate?, :canonicalize => canonicalize?)
          add_triple(attr, subject, predicate, lit)
        end
      end
      
      # Handle the propertyEltList children events in document order
      li_counter = 0 # this will increase for each li we iterate through
      el.children.each do |child|
        next unless child.elem?
        child_ec = ec.clone(child) do |prefix, value|
          prefix(prefix, value)
        end
        predicate = child.uri
        add_debug(child, "propertyElt, predicate: #{predicate}")
        propertyElementURI_check(child)
        
        # Determine the content type of this property element
        text_nodes = child.children.select {|e| e.text? && !e.blank?}
        element_nodes = child.children.select {|c| c.element? }
        add_debug(child, "#{text_nodes.length} text nodes, #{element_nodes.length} element nodes")
        if element_nodes.length > 1
          element_nodes.each do |node|
            add_debug(child, "  node: #{node.to_s}")
          end
        end

        # List expansion
        predicate = ec.li_next if predicate == RDF.li
        
        # Productions based on set of attributes
        
        # All remaining reserved XML Names (See Name in XML 1.0) are now removed from the set.
        # These are, all attribute information items in the set with property [prefix] beginning with xml
        # (case independent comparison) and all attribute information items with [prefix] property having
        # no value and which have [local name] beginning with xml (case independent comparison) are removed.
        # Note that the [base URI] accessor is computed by XML Base before any xml:base attribute information item
        # is deleted.
        attrs = {}
        id = datatype = parseType = resourceAttr = nodeID = nil
        
        child.attribute_nodes.each do |attr|
          if attr.namespace.to_s.empty?
            # The support for a limited set of non-namespaced names is REQUIRED and intended to allow
            # RDF/XML documents specified in [RDF-MS] to remain valid;
            # new documents SHOULD NOT use these unqualified attributes and applications
            # MAY choose to warn when the unqualified form is seen in a document.
            add_debug(el, "Unqualified attribute '#{attr}'")
            #attrs[attr.to_s] = attr.value unless attr.to_s.match?(/^xml/)
          elsif attr.namespace.href == RDF::XML.to_s
            # No production. Lang and base elements already extracted
          elsif attr.namespace.href == RDF.to_uri.to_s
            case attr.name
            when "ID"         then id = attr.value
            when "datatype"   then datatype = attr.value
            when "parseType"  then parseType = attr.value
            when "resource"   then resourceAttr = attr.value
            when "nodeID"     then nodeID = attr.value
            else                   attrs[attr] = attr.value
            end
          else
            attrs[attr] = attr.value
          end
        end
        
        if nodeID && resourceAttr
          add_debug(el, "Cannot have rdf:nodeID and rdf:resource.")
          raise RDF::ReaderError.new("Cannot have rdf:nodeID and rdf:resource.") if validate?
        end

        # Apply character transformations
        id = id_check(el, RDF::NTriples.unescape(id), nil) if id
        resourceAttr = RDF::NTriples.unescape(resourceAttr) if resourceAttr
        nodeID = nodeID_check(el, RDF::NTriples.unescape(nodeID)) if nodeID

        add_debug(child, "attrs: #{attrs.inspect}")
        add_debug(child, "datatype: #{datatype}") if datatype
        add_debug(child, "parseType: #{parseType}") if parseType
        add_debug(child, "resource: #{resourceAttr}") if resourceAttr
        add_debug(child, "nodeID: #{nodeID}") if nodeID
        add_debug(child, "id: #{id}") if id
        
        if attrs.empty? && datatype.nil? && parseType.nil? && element_nodes.length == 1
          # Production resourcePropertyElt

          new_ec = child_ec.clone(nil) do |prefix, value|
            prefix(prefix, value)
          end
          new_node_element = element_nodes.first
          add_debug(child, "resourcePropertyElt: #{node_path(new_node_element)}")
          new_subject = nodeElement(new_node_element, new_ec)
          add_triple(child, subject, predicate, new_subject)
        elsif attrs.empty? && parseType.nil? && element_nodes.length == 0 && text_nodes.length > 0
          # Production literalPropertyElt
          add_debug(child, "literalPropertyElt")
          
          literal_opts = {:validate => validate?, :canonicalize => canonicalize?}
          if datatype
            literal_opts[:datatype] = uri(datatype)
          else
            literal_opts[:language] = child_ec.language
          end
          literal = RDF::Literal.new(child.inner_html, literal_opts)
          add_triple(child, subject, predicate, literal)
          reify(id, child, subject, predicate, literal, ec) if id
        elsif parseType == "Resource"
          # Production parseTypeResourcePropertyElt
          add_debug(child, "parseTypeResourcePropertyElt")

          unless attrs.empty?
            warn = "Resource Property with extra attributes: '#{attrs.inspect}'"
            add_debug(child, warn)
            raise RDF::ReaderError.new(warn) if validate?
          end

          # For element e with possibly empty element content c.
          n = RDF::Node.new
          add_triple(child, subject, predicate, n)

          # Reification
          reify(id, child, subject, predicate, n, child_ec) if id
          
          # If the element content c is not empty, then use event n to create a new sequence of events as follows:
          #
          # start-element(URI := rdf:Description,
          #     subject := n,
          #     attributes := set())
          # c
          # end-element()
          add_debug(child, "compose new sequence with rdf:Description")
          node = child.clone
          pt_attr = node.attribute("parseType")
          node.namespace = pt_attr.namespace
          node.attributes.keys.each {|a| node.remove_attribute(a)}
          node.node_name = "Description"
          new_ec = child_ec.clone(nil, :subject => n) do |prefix, value|
            prefix(prefix, value)
          end
          nodeElement(node, new_ec)
        elsif parseType == "Collection"
          # Production parseTypeCollectionPropertyElt
          add_debug(child, "parseTypeCollectionPropertyElt")

          unless attrs.empty?
            warn = "Resource Property with extra attributes: '#{attrs.inspect}'"
            add_debug(child, warn)
            raise RDF::ReaderError.new(warn) if validate?
          end

          # For element event e with possibly empty nodeElementList l. Set s:=list().
          # For each element event f in l, n := bnodeid(identifier := generated-blank-node-id()) and append n to s to give a sequence of events.
          s = element_nodes.map { RDF::Node.new }
          n = s.first || RDF["nil"]
          add_triple(child, subject, predicate, n)
          reify(id, child, subject, predicate, n, child_ec) if id
          
          # Add first/rest entries for all list elements
          s.each_index do |i|
            n = s[i]
            o = s[i+1]
            f = element_nodes[i]

            new_ec = child_ec.clone(nil) do |prefix, value|
              prefix(prefix, value)
            end
            object = nodeElement(f, new_ec)
            add_triple(child, n, RDF.first, object)
            add_triple(child, n, RDF.rest, o ? o : RDF.nil)
          end
        elsif parseType   # Literal or Other
          # Production parseTypeResourcePropertyElt
          add_debug(child, parseType == "Literal" ? "parseTypeResourcePropertyElt" : "parseTypeOtherPropertyElt (#{parseType})")

          unless attrs.empty?
            warn = "Resource Property with extra attributes: '#{attrs.inspect}'"
            add_debug(child, warn)
            raise RDF::ReaderError.new(warn) if validate?
          end

          if resourceAttr
            warn = "illegal rdf:resource"
            add_debug(child, warn)
            raise RDF::ReaderError.new(warn) if validate?
          end

          object = RDF::Literal.new(child.children, :datatype => RDF.XMLLiteral, :namespaces => child_ec.uri_mappings, :language => ec.language)
          add_triple(child, subject, predicate, object)
        elsif text_nodes.length == 0 && element_nodes.length == 0
          # Production emptyPropertyElt
          add_debug(child, "emptyPropertyElt")

          if attrs.empty? && resourceAttr.nil? && nodeID.nil?
            literal = RDF::Literal.new("", :language => ec.language)
            add_triple(child, subject, predicate, literal)
            
            # Reification
            reify(id, child, subject, predicate, literal, child_ec) if id
          else
            if resourceAttr
              resource = ec.base.join(resourceAttr)
            elsif nodeID
              resource = bnode(nodeID)
            else
              resource = RDF::Node.new
            end

            # produce triples for attributes
            attrs.each_pair do |attr, val|
              add_debug(el, "attr: #{attr.name}='#{val}'")
              
              if attr.uri.to_s == RDF.type.to_s
                add_triple(child, resource, RDF.type, val)
              else
                # Check for illegal attributes
                next unless is_propertyAttr?(attr)

                # Attributes not in RDF.type
                lit = RDF::Literal.new(val, :language => child_ec.language)
                add_triple(child, resource, attr.uri, lit)
              end
            end
            add_triple(child, subject, predicate, resource)
            
            # Reification
            reify(id, child, subject, predicate, resource, child_ec) if id
          end
        end
      end
      
      # Return subject
      subject
    end
    
    private
    # Reify subject, predicate, and object given the EvaluationContext (ec) and current XMl element (el)
    def reify(id, el, subject, predicate, object, ec)
      add_debug(el, "reify, id: #{id}")
      rsubject = ec.base.join("#" + id)
      add_triple(el, rsubject, RDF.subject, subject)
      add_triple(el, rsubject, RDF.predicate, predicate)
      add_triple(el, rsubject, RDF.object, object)
      add_triple(el, rsubject, RDF.type, RDF["Statement"])
    end

    # Figure out the subject from the element.
    def parse_subject(el, ec)
      old_property_check(el)
      
      nodeElementURI_check(el)
      about = el.attribute("about")
      id = el.attribute("ID")
      nodeID = el.attribute("nodeID")
      
      if nodeID && about
        add_debug(el, "Cannot have rdf:nodeID and rdf:about.")
        raise RDF::ReaderError.new("Cannot have rdf:nodeID and rdf:about.") if validate?
      elsif nodeID && id
        add_debug(el, "Cannot have rdf:nodeID and rdf:ID.")
        raise RDF::ReaderError.new("Cannot have rdf:nodeID and rdf:ID.") if validate?
      end

      case
      when id
        add_debug(el, "parse_subject, id: '#{RDF::NTriples.unescape(id.value)}'")
        id_check(el, RDF::NTriples.unescape(id.value), ec.base) # Returns URI
      when nodeID
        # The value of rdf:nodeID must match the XML Name production
        nodeID = nodeID_check(el, RDF::NTriples.unescape(nodeID.value))
        add_debug(el, "parse_subject, nodeID: '#{nodeID}")
        bnode(nodeID)
      when about
        about = RDF::NTriples.unescape(about.value)
        add_debug(el, "parse_subject, about: '#{about}'")
        ec.base.join(about)
      else
        add_debug(el, "parse_subject, BNode")
        RDF::Node.new
      end
    end
    
    # ID attribute must be an NCName
    def id_check(el, id, base)
      unless NC_REGEXP.match(id)
        warn = "ID addtribute '#{id}' must be a NCName"
        add_debug(el, warn)
        raise RDF::ReaderError.new(warn) if validate?
      end
      # ID may only be specified once for the same URI
      if base
        uri = uri(base, "##{id}")
        if prefix(id) && RDF::URI(prefix(id)) == uri
          warn = "ID addtribute '#{id}' may only be defined once for the same URI"
          add_debug(el, warn)
          raise RDF::ReaderError.new(warn) if validate?
        end
        
        RDF::URI(prefix(id, uri))
        # Returns URI, in this case
      else
        id
      end
    end
    
    # nodeID must be an XML Name
    # nodeID must pass Production rdf-id
    def nodeID_check(el, nodeID)
      if NC_REGEXP.match(nodeID)
        nodeID
      else
        add_debug(el, "nodeID addtribute '#{nodeID}' must be an XML Name")
        raise RDF::ReaderError.new("nodeID addtribute '#{nodeID}' must be a NCName") if validate?
        nil
      end
    end
    
    # Is this attribute a Property Attribute?
    def is_propertyAttr?(attr)
      if ([RDF.Description.to_s, RDF.li.to_s] + OLD_TERMS).include?(attr.uri.to_s)
        warn = "Invalid use of rdf:#{attr.name}"
        add_debug(attr, warn)
        raise RDF::ReaderError.new(warn) if validate?
        return false
      end
      !CORE_SYNTAX_TERMS.include?(attr.uri.to_s) && attr.namespace && attr.namespace.href != RDF::XML.to_s
    end
    
    # Check Node Element name
    def nodeElementURI_check(el)
      if (CORE_SYNTAX_TERMS + [RDF.li.to_s] + OLD_TERMS).include?(el.uri.to_s)
        warn = "Invalid use of rdf:#{el.name}"
        add_debug(el, warn)
        raise RDF::ReaderError.new(warn) if validate?
      end
    end

    # Check Property Element name
    def propertyElementURI_check(el)
      if (CORE_SYNTAX_TERMS + [RDF.Description.to_s] + OLD_TERMS).include?(el.uri.to_s)
        warn = "Invalid use of rdf:#{el.name}"
        add_debug(el, warn)
        raise RDF::ReaderError.new(warn) if validate?
      end
    end

    # Check for the use of an obsolete RDF property
    def old_property_check(el)
      el.attribute_nodes.each do |attr|
        if OLD_TERMS.include?(attr.uri.to_s)
          add_debug(el, "Obsolete attribute '#{attr.uri}'")
          raise RDF::ReaderError.new("Obsolete attribute '#{attr.uri}'") if validate?
        end
      end
    end
    
    def uri(value, append = nil)
      value = RDF::URI.new(value)
      value = value.join(append) if append
      value.validate! if validate?
      value.canonicalize! if canonicalize?
      value = RDF::URI.intern(value) if intern?
      value
    end

  end
end
