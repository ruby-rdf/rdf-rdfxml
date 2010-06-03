$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'rdf'

module RDF
  ##
  # **`RDF::RDFXML`** is an RDF/XML plugin for RDF.rb.
  #
  # @example Requiring the `RDF::RDFXML` module
  #   require 'rdf/rdfxml'
  #
  # @example Parsing RDF statements from an XHTML+RDFa file
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
  module RDFa
    require 'rdfxml/format'
    require 'rdfxml/vocab'
    require 'n3/patches/array_hacks'
    require 'n3/patches/nokogiri_hacks'
    require 'n3/patches/rdf_escape'
    autoload :Reader,  'rdf/rdfxml/reader'
    autoload :Writer,  'rdf/rdfxml/writer'
    autoload :VERSION, 'rdf/rdfxml/version'
  end
end