# coding: utf-8
$:.unshift "."
require 'spec_helper'

describe RDF::RDFXML::Reader do
  describe "w3c rdfcore tests" do
    require 'suite_helper'

    %w(manifest.ttl).each do |man|
      Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.name}" do
              t.logger = RDF::Spec.logger
              t.logger.info t.inspect
              t.logger.info "source:\n#{t.input.read}"

              reader = RDF::RDFXML::Reader.new(t.input,
                  base_uri: t.base,
                  canonicalize: false,
                  validate: t.syntax?,
                  logger: t.logger)

              repo = RDF::Repository.new

              if reader.instance_variable_get(:@library) == :rexml
                pending("no namespace attributes") if t.name == "unrecognised-xml-attributes-test002"
                pending("XML-C14XL") if t.name == "xml-canon-test001"
              end

              if t.positive_test?
                begin
                  repo << reader
                rescue Exception => e
                  expect(e.message).to produce("Not exception #{e.inspect}", t.debug + e.backtrace.unshift("Backtrace:"))
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
