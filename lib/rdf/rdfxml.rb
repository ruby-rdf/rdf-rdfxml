$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
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
    require 'rdfxml/format'
    require 'rdfxml/vocab'
    require 'rdfxml/patches/array_hacks'
    require 'rdfxml/patches/nokogiri_hacks'
    require 'rdfxml/patches/rdf_escape'
    autoload :Reader,  'rdfxml/reader'
    autoload :Writer,  'rdfxml/writer'
    autoload :VERSION, 'rdfxml/version'
    
    # Fixme: RDF.to_s should generate this, but it doesn't
    RDF_NS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  end
end