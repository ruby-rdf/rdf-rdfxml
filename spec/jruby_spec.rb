# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/reader'
require 'rdf/vocab'

# Some specific issues that fail with jRuby to be resolved
have_nokogiri = true
begin
  require 'nokogiri'
rescue LoadError
  have_nokogiri = false
end

describe "Nokogiri::XML", skip: ("Nokogiri not loaded" unless have_nokogiri) do
  describe "parse" do
    it "parses namespaced elements without a namespace" do
      expect(Nokogiri::XML.parse("<dc:sup>bar</dc:sup>").root).not_to be_nil
    end
  end
end

describe RDF::RDFXML::Writer, skip: ("Nokogiri not loaded" unless have_nokogiri) do
  context "resource without type" do
    subject do
      @graph = RDF::Repository.new << [RDF::URI.new("http://release/"), RDF::URI("http://purl.org/dc/terms/title"), "foo"]
      serialize(max_depth: 1, attributes: :untyped)
    end

    {
      "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
      "/rdf:RDF/rdf:Description/@dc:title" => "foo"
    }.each do |path, value|
      it "returns #{value.inspect} for xpath #{path}" do
        expect(subject).to have_xpath(path, value, {})
      end
    end
  end

  # Serialize  @graph to a string and compare against regexps
  def serialize(options = {})
    @debug = []
    result = RDF::RDFXML::Writer.buffer({logger: false, standard_prefixes: true}.merge(options)) do |writer|
      writer << @graph
    end
    require 'cgi'
    puts CGI.escapeHTML(result) if $verbose
    result
  end
end

