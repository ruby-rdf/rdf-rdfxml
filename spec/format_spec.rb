$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/format'

describe RDF::RDFXML::Format do
  before :each do
    @format_class = RDF::RDFXML::Format
  end

  include RDF_Format

  describe ".for" do
    formats = [
      :rdfxml,
      'etc/doap.rdf',
      {:file_name      => 'etc/doap.rdf'},
      {:file_extension => 'rdf'},
      {:content_type   => 'application/rdf+xml'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        RDF::Format.for(arg).should == @format_class
      end
    end

    {
      :rdfxml   => '<rdf:RDF about="foo"></rdf:RDF>',
    }.each do |sym, str|
      it "detects #{sym}" do
        @format_class.for {str}.should == @format_class
      end
    end
  end

  describe "#to_sym" do
    specify {@format_class.to_sym.should == :rdfxml}
  end

  describe ".detect" do
    {
      :rdfxml => '<rdf:RDF about="foo"></rdf:RDF>',
    }.each do |sym, str|
      it "detects #{sym}" do
        @format_class.detect(str).should be_true
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
        @format_class.detect(str).should be_false
      end
    end

    describe RDF::RDFXML::RDFFormat do
      it "discovers with :rdf" do
        RDF::Format.for(:rdf).should == RDF::RDFXML::RDFFormat
      end

      it "should discover :rdf" do
        RDF::Format.for(:rdf).reader.should == RDF::RDFXML::Reader
        RDF::Format.for(:rdf).writer.should == RDF::RDFXML::Writer
      end
    end
  end
end
