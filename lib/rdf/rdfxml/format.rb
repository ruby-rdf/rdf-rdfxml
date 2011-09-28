module RDF::RDFXML
  ##
  # RDFXML format specification.
  #
  # @example Obtaining an RDFXML format class
  #   RDF::Format.for(:rdf)         # RDF::RDFXML::Format
  #   RDF::Format.for(:rdfxml)      # RDF::RDFXML::Format
  #   RDF::Format.for("etc/foaf.xml")
  #   RDF::Format.for(:file_name      => "etc/foaf.xml")
  #   RDF::Format.for(:file_extension => "xml")
  #   RDF::Format.for(:file_extension => "rdf")
  #   RDF::Format.for(:content_type   => "application/xml")
  #   RDF::Format.for(:content_type   => "application/rdf+xml")
  #
  # @example Obtaining serialization format MIME types
  #   RDF::Format.content_types      #=> {"application/rdf+xml" => [RDF::RDFXML::Format]}
  #
  # @example Obtaining serialization format file extension mappings
  #   RDF::Format.file_extensions    #=> {:rdf => "application/rdf+xml"}
  #
  # @see http://www.w3.org/TR/rdf-testcases/#ntriples
  class Format < RDF::Format
    content_type     'application/xml', :extension => :xml
    content_type     'application/rdf+xml', :extension => :rdf
    content_encoding 'utf-8'

    reader { RDF::RDFXML::Reader }
    writer { RDF::RDFXML::Writer }

    ##
    # Sample detection to see if it matches RDF/XML (not Microdata or RDFa)
    #
    # Use a text sample to detect the format of an input file. Sub-classes implement
    # a matcher sufficient to detect probably format matches, including disambiguating
    # between other similar formats.
    #
    # @param [String] sample Beginning several bytes (~ 1K) of input.
    # @return [Boolean]
    def self.detect(sample)
      sample.match(/<(\w+:)?(RDF)/)
    end
  end
  
  # Aliases for this format
  #
  # This allows the following:
  #
  # @example Obtaining an RDFXML format class
  #   RDF::Format.for(:xml)         # RDF::RDFXML::XML
  #   RDF::Format.for(:xml).reader  # RDF::RDFXML::Reader
  #   RDF::Format.for(:xml).writer  # RDF::RDFXML::Writer
  class XML < RDF::Format
    reader { RDF::RDFXML::Reader }
    writer { RDF::RDFXML::Writer }
  end
end
