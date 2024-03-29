# coding: utf-8
require_relative 'spec_helper'
require 'rdf/rdfxml'

describe RDF::RDFXML::Reader do
  describe "w3c rdfcore tests" do
    require_relative 'suite_helper'

    %w(rdf11/rdf-xml/manifest.ttl).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.name}" do
              t.logger = RDF::Spec.logger
              t.logger.info t.inspect
              t.logger.info "source:\n#{t.input}"

              reader = RDF::RDFXML::Reader.new(t.input,
                  base_uri: t.base,
                  canonicalize: false,
                  validate: t.syntax?,
                  logger: t.logger)

              repo = RDF::Repository.new

              if reader.instance_variable_get(:@library) == :rexml
                pending("no namespace attributes") if t.name == "unrecognised-xml-attributes-test002"
              end
              pending("XML-C14XL") if t.name == "xml-canon-test001"

              if t.positive_test?
                begin
                  repo << reader
                rescue Exception => e
                  t.logger.debug e.e.backtrace.unshift("Backtrace:").join("\n")
                  expect(e.message).to produce("Not exception #{e.inspect}", t.logger)
                end
              else
                expect {
                  repo << reader
                }.to raise_error(RDF::ReaderError)
              end

              if t.evaluate? && t.positive_test?
                output_repo = RDF::Repository.load(t.result, format: :ntriples, base_uri: t.base)
                expect(repo).to be_equivalent_graph(output_repo, t)
              elsif !t.evaluate?
                expect(repo).to be_a(RDF::Enumerable)
              end
            end
          end
        end
      end
    end
  end
end unless ENV['CI'] # Not for continuous integration
