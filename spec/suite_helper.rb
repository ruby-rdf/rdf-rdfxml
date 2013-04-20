# -*- encoding: utf-8 -*-
# Spira class for manipulating test-manifest style test suites.
# Used for SWAP tests
require 'json/ld'
require 'rdf/rdfxml'

module Fixtures
  module SuiteTest
    BASE = "http://www.w3.org/2000/10/rdf-tests/rdfcore/"
    CONTEXT = JSON.parse(%q({
      "xsd":          "http://www.w3.org/2001/XMLSchema#",
      "rdfs":         "http://www.w3.org/2000/01/rdf-schema#",
      "test":         "http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#",

      "description":  "test:description",
      "status":       "test:status",
      "warning":      "test:warning",
      "approval":     {"@id": "test:approval", "@type": "@id"},
      "issue":        {"@id": "test:issue", "@type": "@id"},
      "document":     {"@id": "test:document", "@type": "@id"},
      "discussion":   {"@id": "test:discussion", "@type": "@id"},
      "inputDocument": {"@id": "test:inputDocument", "@type": "@id"},
      "outputDocument":{"@id": "test:outputDocument", "@type": "@id"}
    }))

    class Manifest
      def self.open(file)
        g = RDF::Graph.load(file, :format => :rdfxml)
        JSON::LD::API.fromRDF(g) do |expanded|
          JSON::LD::API.compact(expanded, CONTEXT) do |compacted|
            compacted['@graph'].each do |node|
              yield TestCase.new(node)
            end
          end
        end
      end
    end

    class TestCase < JSON::LD::Resource
      attr_accessor :debug

      def name
        id.to_s.split("#").last
      end

      # Alias data and query
      def input
        RDF::Util::File.open_file(inputDocument)
      end

      def result
        RDF::Util::File.open_file(outputDocument)
      end

      def positive_test?
        attributes['@type'].include?('Positive')
      end

      def negative_test?
        !positive_test?
      end

      def parser_test?
        attributes['@type'].include?('ParserTest')
      end

      def entailment_test?
        attributes['@type'].include?('EntailmentTest')
      end

      def inspect
        super.sub('>', "\n" +
          "  parser?: #{parser_test?.inspect}\n" +
          "  positive?: #{positive_test?.inspect}\n" +
          ">"
        )
      end
    end
  end
end
