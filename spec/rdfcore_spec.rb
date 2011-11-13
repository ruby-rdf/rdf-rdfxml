# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/reader'
require 'rdfcore_test'

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe "RDF::RDFXML::Reader" do
  # W3C Test suite from http://www.w3.org/2000/10/rdf-tests/rdfcore/
  describe "w3c rdfcore tests" do
    
    # Positive parser tests should raise errors.
    describe "positive parser tests" do
      Fixtures::TestCase::PositiveParserTest.each do |t|
        next unless t.status == "APPROVED"
        #next unless t.about =~ /rdfms-rdf-names-use/
        #next unless t.name =~ /11/
        #puts t.inspect
        specify "#{t.name}: " + (t.description || "#{t.inputDocument} against #{t.outputDocument}") do
          begin
            graph = RDF::Graph.new << RDF::RDFXML::Reader.new(t.input,
              :base_uri => t.inputDocument,
              :validate => false,
              :debug => t.debug)

            # Parse result graph
            #puts "parse #{self.outputDocument} as #{RDF::Reader.for(self.outputDocument)}"
            format = detect_format(t.output)
            output_graph = RDF::Graph.load(t.outputDocument, :format => format, :base_uri => t.inputDocument)
            puts "result: #{CGI.escapeHTML(graph.dump(:ntriples))}" if ::RDF::N3::debug?
            graph.should be_equivalent_graph(output_graph, t)
          rescue RSpec::Expectations::ExpectationNotMetError => e
            if t.inputDocument =~ %r(xml-literal|xml-canon)
              pending("XMLLiteral canonicalization not implemented yet")
            else
              raise
            end
          end
        end
      end
    end
    
    # Negative parser tests should raise errors.
    describe "negative parser tests" do
      Fixtures::TestCase::NegativeParserTest.each do |t|
        next unless t.status == "APPROVED"
        #next unless t.about =~ /rdfms-empty-property-elements/
        #next unless t.name =~ /1/
        #puts t.inspect
        specify "test #{t.name}: #{t.description || t.inputDocument}" do
          lambda do
            RDF::Graph.new << RDF::RDFXML::Reader.new(t.input,
              :base_uri => t.inputDocument,
              :validate => true)
          end.should raise_error(RDF::ReaderError)
        end
      end
    end
  end
  
  def parse(input, options)
    @debug = []
    graph = RDF::Graph.new
    RDF::RDFXML::Reader.new(input, options.merge(:debug => @debug)).each do |statement|
      graph << statement
    end
    graph
  end
end
