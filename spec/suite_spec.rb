# coding: utf-8
$:.unshift "."
require 'spec_helper'

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe "RDF::RDFXML::Reader" do
  # W3C Test suite from http://www.w3.org/2000/10/rdf-tests/rdfcore/
  describe "w3c rdfcore tests" do
    require 'suite_helper'

    %w(manifest.rdf).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |t|
        next unless t.parser_test? && t.status == "APPROVED"
        specify t.id do
          t.debug = [t.inspect, "source:", t.input.read]

          graph = RDF::Graph.new

          if t.positive_test?
            begin
              reader = RDF::RDFXML::Reader.new(t.input,
                :base_uri => t.inputDocument,
                :canonicalize => false,
                :validate => false,
                :debug => t.debug)

              graph << reader
            rescue Exception => e
              e.message.should produce("Not exception #{e.inspect}", t.debug)
            end

            output_graph = RDF::Graph.load(t.outputDocument, :format => :ntriples)
            graph.should be_equivalent_graph(output_graph, t)
          else
            lambda {
              reader = RDF::RDFXML::Reader.new(t.input,
                :base_uri => t.inputDocument,
                :canonicalize => false,
                :validate => true,
                :debug => t.debug)

              graph << reader
              graph.dump(:ntriples).should produce("", t.debug)
            }.should raise_error(RDF::ReaderError)
          end
        end
      end
    end
  end
end unless ENV['CI'] # Not for continuous integration
