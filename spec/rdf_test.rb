# Spira class for manipulating test-manifest style test suites.
# Used for SWAP tests
require 'spira'
require 'rdf/n3'
require 'open-uri'

module Fixtures
  module TestCase
    class Test < RDF::Vocabulary("http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#"); end

    class Entry
      attr_accessor :debug
      attr_accessor :compare
      include Spira::Resource

      property :description,    :predicate => Test.description,   :type => XSD.string
      property :status,         :predicate => Test.status,        :type => XSD.string
      property :warning,        :predicate => Test.warning,       :type => XSD.string
      property :approval,       :predicate => Test.approval
      property :issue,          :predicate => Test.issue
      property :document,       :predicate => Test.document
      property :discussion,     :predicate => Test.discussion
      property :inputDocument,  :predicate => Test.inputDocument
      property :outputDocument, :predicate => Test.outputDocument

      def name
        subject.to_s.split("#").last
      end

      def input
        Kernel.open(self.inputDocument)
      end
      
      def output
        self.outputDocument ? Kernel.open(self.outputDocument) : ""
      end

      def information; self.description; end
      
      def inspect
        "[#{self.class.to_s} " + %w(
          subject
          description
          inputDocument
          outputDocument
        ).map {|a| v = self.send(a); "#{a}='#{v}'" if v}.compact.join(", ") +
        "]"
      end

      # Run test case, yields input for parser to create triples
      def run_test(options = {})
        # Run
        graph = yield
        
        return unless self.outputDocument

        case self.compare
        when :none
          # Don't check output, just parse to graph
        when :array
          @parser.graph.should be_equivalent_graph(self.output, self)
        else
          #puts "parse #{self.outputDocument} as #{RDF::Reader.for(self.outputDocument)}"
          format = detect_format(self.output)
          output_graph = RDF::Graph.load(self.outputDocument, :format => format, :base_uri => self.inputDocument)
          puts "result: #{CGI.escapeHTML(graph.to_ntriples)}" if ::RDF::N3::debug?
          graph.should Matchers::be_equivalent_graph(output_graph, self)
        end
      end
    end
    
    class PositiveParserTest < Entry
      default_source :entries
      type Test.PositiveParserTest
    end

    class NegativeParserTest < Entry
      default_source :entries
      type Test.NegativeParserTest
    end
    
    class MiscellaneousTest < Entry
      default_source :entries
      type Test.MiscellaneousTest
    end

    repo = RDF::Repository.load("http://www.w3.org/2000/10/rdf-tests/rdfcore/Manifest.rdf")
    Spira.add_repository! :entries, repo
  end
end