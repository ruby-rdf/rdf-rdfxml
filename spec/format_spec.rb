$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/format'

describe RDF::RDFXML::Format do
  it_behaves_like 'an RDF::Format' do
    let(:format_class) {RDF::RDFXML::Format}
  end

  describe ".for" do
    formats = [
      :rdfxml,
      'etc/doap.rdf',
      {:file_name      => 'etc/doap.rdf'},
      {:file_extension => 'rdf'},
      {:content_type   => 'application/rdf+xml'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        expect(RDF::Format.for(arg)).to eq described_class
      end
    end

    {
      :rdfxml   => '<rdf:RDF about="foo"></rdf:RDF>',
    }.each do |sym, str|
      it "detects #{sym}" do
        expect(RDF::Format.for {str}).to eq described_class
      end
    end
  end

  describe "#to_sym" do
    specify {expect(described_class.to_sym).to eq :rdfxml}
  end

  describe ".detect" do
    {
      :rdfxml => '<rdf:RDF about="foo"></rdf:RDF>',
    }.each do |sym, str|
      it "detects #{sym}" do
        expect(described_class.detect(str)).to be_truthy
      end
    end

    {
      :n3                   => "@prefix foo: <bar> .\nfoo:bar = {<a> <b> <c>} .",
      :nquads               => "<a> <b> <c> <d> . ",
      :jsonld               => '{"@context" => "foo"}',
      :ntriples             => "<a> <b> <c> .",
      :microdata            => '<div itemref="bar"></div>',
      :multi_line           => '<a>\n  <b>\n  "literal"\n .',
      :rdfa                 => '<div about="foo"></div>',
      :turtle               => "@prefix foo: <bar> .\n foo:a foo:b <c> .",
      :STRING_LITERAL1      => %(<a> <b> 'literal' .),
      :STRING_LITERAL2      => %(<a> <b> "literal" .),
      :STRING_LITERAL_LONG1 => %(<a> <b> '''\nliteral\n''' .),
      :STRING_LITERAL_LONG2 => %(<a> <b> """\nliteral\n""" .),
    }.each do |sym, str|
      it "does not detect #{sym}" do
        expect(described_class.detect(str)).to be_falsey
      end
    end

    describe RDF::RDFXML::RDFFormat do
      it "discovers with :rdf" do
        expect(RDF::Format.for(:rdf)).to eq RDF::RDFXML::RDFFormat
      end

      it "should discover :rdf" do
        expect(RDF::Format.for(:rdf).reader).to eq RDF::RDFXML::Reader
        expect(RDF::Format.for(:rdf).writer).to eq RDF::RDFXML::Writer
      end
    end
  end
end
