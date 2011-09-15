$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/format'

describe RDF::RDFXML::Format do
  before :each do
    @format_class = RDF::RDFXML::Format
  end

  it_should_behave_like RDF_Format

  describe ".for" do
    formats = [
      :rdfxml,
      'etc/doap.rdf', 'etc/doap.xml',
      {:file_name      => 'etc/doap.rdf'},
      {:file_name      => 'etc/doap.xml'},
      {:file_extension => 'rdf'},
      {:file_extension => 'xml'},
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

    it "should discover 'xml'" do
      RDF::Format.for(:xml).reader.should == RDF::RDFXML::Reader
      RDF::Format.for(:xml).writer.should == RDF::RDFXML::Writer
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
  end
end
