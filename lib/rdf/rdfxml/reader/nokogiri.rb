module RDF::RDFXML
  class Reader < RDF::Reader
    ##
    # Nokogiri implementation of an XML parser.
    #
    # @see http://nokogiri.org/
    module Nokogiri
      ##
      # Returns the name of the underlying XML library.
      #
      # @return [Symbol]
      def self.library
        :nokogiri
      end

      # Proxy class to implement uniform element accessors
      class NodeProxy
        attr_reader :node
        attr_reader :parent

        def initialize(node, parent = nil)
          @node = node
          @parent = parent
        end

        ##
        # Element language
        #
        # From HTML5 [3.2.3.3]
        #   If both the lang attribute in no namespace and the lang attribute in the XML namespace are set
        #   on an element, user agents must use the lang attribute in the XML namespace, and the lang
        #   attribute in no namespace must be ignored for the purposes of determining the element's
        #   language.
        #
        # @return [String]
        def language
          attribute_with_ns("lang", RDF::XML.to_s)
        end

        ##
        # Return xml:base on element, if defined
        #
        # @return [String]
        def base
          attribute_with_ns("base", RDF::XML.to_s)
        end

        ##
        # Monkey patch attribute_with_ns, to insure nil is returned for #null?
        #
        # Get the attribute node with name and namespace
        #
        # @param [String] name
        # @param [String] namespace
        # @return [Nokogiri::XML::Attr]
        def attribute_with_ns(name, namespace)
          a = @node.attribute_with_ns(name, namespace)

          (a.respond_to?(:null?) && a.null?) ? nil : a # to ensure FFI Pointer compatibility
        end
        
        def display_path
          @display_path ||= begin
            path = []
            path << parent.display_path if parent
            path << @node.name
            case @node
            when ::Nokogiri::XML::Element then path.join("/")
            when ::Nokogiri::XML::Attr    then path.join("@")
            else path.join("?")
            end
          end
        end

        ##
        # Return true of all child elements are text
        #
        # @return [Array<:text, :element, :attribute>]
        def text_content?
          @text_content ||= @node.children.all? {|c| c.text?}
        end

        ##
        # Retrieve XMLNS definitions for this element
        #
        # @return [Hash{String => String}]
        def namespaces
          @namespaces ||= @node.namespace_definitions.inject({}) {|memo, ns| memo[ns.prefix] = ns.href.to_s; memo }
        end
        
        ##
        # Children of this node
        #
        # @return [NodeSetProxy]
        def children
          @children ||= NodeSetProxy.new(@node.children, self)
        end
        
        # Ancestors of this element, in order
        def ancestors
          @ancestors ||= parent ? parent.ancestors + [parent] : []
        end

        ##
        # Inner text of an element. Decode Entities
        #
        # @return [String]
        #def inner_text
        #  coder = HTMLEntities.new
        #  coder.decode(@node.inner_text)
        #end

        def attribute_nodes
          @attribute_nodes ||= NodeSetProxy.new(@node.attribute_nodes, self)
        end

        def xpath(*args)
          @node.xpath(*args).map {|n| NodeProxy.new(n)}
        end

        # For jRuby, there is a bug that prevents the namespace from being set on an element
        if RUBY_PLATFORM == "java"
          def add_namespace(prefix, href)
            @def_namespace = href if prefix.nil?
            @node.add_namespace(prefix, href)
          end

          def namespace
            @def_namespace || @node.namespace
          end
        else
          def add_namespace(prefix, href)
            @node.add_namespace(prefix, href)
          end

          def namespace
            @node.namespace
          end
        end

        # URI of namespace + node_name
        def uri
          ns = namespace || RDF::XML.to_s
          ns = ns.href if ns.respond_to?(:href)
          RDF::URI.intern(ns + self.node_name)
        end

        ##
        # Proxy for everything else to @node
        def method_missing(method, *args)
          @node.send(method, *args)
        end
      end

      ##
      # NodeSet proxy
      class NodeSetProxy
        attr_reader :node_set
        attr_reader :parent

        def initialize(node_set, parent)
          @node_set = node_set
          @parent = parent
        end

        ##
        # Return a proxy for each child
        #
        # @yield(child)
        # @yieldparam(NodeProxy)
        def each
          @node_set.each do |c|
            yield NodeProxy.new(c, parent)
          end
        end
        
        ##
        # Return selected NodeProxies based on selection
        #
        # @yield(child)
        # @yieldparam(NodeProxy)
        # @return [Array[NodeProxy]]
        def select
          @node_set.to_a.map {|n| NodeProxy.new(n, parent)}.select do |c|
            yield c
          end
        end

        ##
        # Proxy for everything else to @node_set
        def method_missing(method, *args)
          @node_set.send(method, *args)
        end
      end

      ##
      # Initializes the underlying XML library.
      #
      # @param  [Hash{Symbol => Object}] options
      # @return [void]
      def initialize_xml(input, options = {})
        require 'nokogiri' unless defined?(::Nokogiri)
        @doc = case input
        when ::Nokogiri::XML::Document
          input
        else
          # Try to detect charset from input
          options[:encoding] ||= input.charset if input.respond_to?(:charset)
          
          # Otherwise, default is utf-8
          options[:encoding] ||= 'utf-8'

          ::Nokogiri::XML.parse(input, base_uri.to_s, options[:encoding]) do |config|
            config.noent
          end
        end
      end

      # Accessor methods to mask native elements & attributes
      
      ##
      # Return proxy for document root
      def root
        @root ||= NodeProxy.new(@doc.root) if @doc && @doc.root
      end
      
      ##
      # Document errors
      def doc_errors
        @doc.errors
      end
    end
  end
end
