$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))
require 'rdf'

module RDF
  ##
  # **`RDF::RDFXML`** is an RDF/XML plugin for RDF.rb.
  #
  # @example Requiring the `RDF::RDFXML` module
  #   require 'rdf/rdfxml'
  #
  # @example Parsing RDF statements from an XHTML+RDFXML file
  #   RDF::RDFXML::Reader.open("etc/foaf.xml") do |reader|
  #     reader.each_statement do |statement|
  #       puts statement.inspect
  #     end
  #   end
  #
  # @see http://rdf.rubyforge.org/
  # @see http://www.w3.org/TR/REC-rdf-syntax/
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  module RDFXML
    require 'rdf/rdfxml/format'
    require 'rdf/rdfxml/vocab'
    require 'rdf/rdfxml/patches/array_hacks'
    require 'rdf/rdfxml/patches/literal_hacks'
    require 'rdf/rdfxml/patches/nokogiri_hacks'
    autoload :Reader,  'rdf/rdfxml/reader'
    autoload :Writer,  'rdf/rdfxml/writer'
    autoload :VERSION, 'rdf/rdfxml/version'
    autoload :XML,     'rdf/rdfxml/vocab'
    
    def self.debug?; @debug; end
    def self.debug=(value); @debug = value; end
  end
end
