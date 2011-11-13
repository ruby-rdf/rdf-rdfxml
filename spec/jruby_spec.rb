# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'nokogiri'
require 'rdf/spec/reader'

# Some specific issues that fail with jRuby to be resolved
describe Nokogiri::XML do
  describe "parse" do
    it "parses namespaced elements without a namespace" do
      Nokogiri::XML.parse("<dc:sup>bar</dc:sup>").root.should_not be_nil
    end
  end
end

describe RDF::RDFXML::Writer do
  context "resource without type" do
    subject do
      @graph = RDF::Graph.new << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      serialize(:max_depth => 1, :attributes => :untyped)
    end

    {
      "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
      "/rdf:RDF/rdf:Description/@dc:title" => "foo"
    }.each do |path, value|
      it "returns #{value.inspect} for xpath #{path}" do
        subject.should have_xpath(path, value, {})
      end
    end
  end

  # Serialize  @graph to a string and compare against regexps
  def serialize(options = {})
    @debug = []
    result = RDF::RDFXML::Writer.buffer({:debug => @debug, :standard_prefixes => true}.merge(options)) do |writer|
      writer << @graph
    end
    require 'cgi'
    puts CGI.escapeHTML(result) if $verbose
    result
  end
end

