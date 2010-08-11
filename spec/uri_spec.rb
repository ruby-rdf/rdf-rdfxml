# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::URI do
  class EXa < RDF::Vocabulary("http://example.org/foo/"); end
  class EXb < RDF::Vocabulary("http://example.org/foo#"); end
  class EXc < RDF::Vocabulary("http://example.org/foo"); end
  
  subject { RDF::URI.new("http://example.org")}
  
  context "join" do
    it "should append fragment to uri" do
      subject.join("foo").to_s.should == "http://example.org/foo"
    end

    it "should append another fragment" do
      subject.join("foo#bar").to_s.should == "http://example.org/foo#bar"
    end

    it "should append another URI" do
      subject.join(RDF::URI.new("foo#bar")).to_s.should == "http://example.org/foo#bar"
    end

    describe "utf-8 escaped" do
      {
        %(http://a/D%C3%BCrst)                => %(<http://a/D%C3%BCrst>),
        %(http://a/D\u00FCrst)                => %(<http://a/D\\u00FCrst>),
        %(http://b/Dürst)                     => %(<http://b/D\\u00FCrst>),
        %(http://a/\u{15678}another)          => %(<http://a/\\U00015678another>),
      }.each_pair do |uri, dump|
        it "should dump #{uri} as #{dump}" do
          RDF::URI.new(uri).to_ntriples.should == dump
        end
      end
    end if defined?(::Encoding) # Only works properly in Ruby 1.9

    describe "join" do
      {
        %w(http://foo ) =>  "<http://foo>",
        %w(http://foo a) => "<http://foo/a>",
        %w(http://foo /a) => "<http://foo/a>",
        %w(http://foo #a) => "<http://foo#a>",

        %w(http://foo/ ) =>  "<http://foo/>",
        %w(http://foo/ a) => "<http://foo/a>",
        %w(http://foo/ /a) => "<http://foo/a>",
        %w(http://foo/ #a) => "<http://foo/#a>",

        %w(http://foo# ) =>  "<http://foo#>",
        %w(http://foo# a) => "<http://foo/a>",
        %w(http://foo# /a) => "<http://foo/a>",
        %w(http://foo# #a) => "<http://foo#a>",

        %w(http://foo/bar ) =>  "<http://foo/bar>",
        %w(http://foo/bar a) => "<http://foo/a>",
        %w(http://foo/bar /a) => "<http://foo/a>",
        %w(http://foo/bar #a) => "<http://foo/bar#a>",

        %w(http://foo/bar/ ) =>  "<http://foo/bar/>",
        %w(http://foo/bar/ a) => "<http://foo/bar/a>",
        %w(http://foo/bar/ /a) => "<http://foo/a>",
        %w(http://foo/bar/ #a) => "<http://foo/bar/#a>",

        %w(http://foo/bar# ) =>  "<http://foo/bar#>",
        %w(http://foo/bar# a) => "<http://foo/a>",
        %w(http://foo/bar# /a) => "<http://foo/a>",
        %w(http://foo/bar# #a) => "<http://foo/bar#a>",

        %w(http://foo/bar# #D%C3%BCrst) => "<http://foo/bar#D%C3%BCrst>",
        %w(http://foo/bar# #Dürst) => "<http://foo/bar#D\\u00FCrst>",
      }.each_pair do |input, result|
        it "should create <#{result}> from <#{input[0]}> and '#{input[1]}'" do
          RDF::URI.new(input[0]).join(input[1].to_s).to_ntriples.should == result
        end
      end
    end
  end

  context "qname" do
    it "should create [:rdf, :foo]" do
      RDF.foo.qname.should == [:rdf, :foo]
    end

    it "should create [:rdfs, nil]" do
      RDF::RDFS.to_uri.qname.should == [:rdfs, nil]
    end

    it "should find with trailing /" do
      EXa.bar.qname.should == [:exa, :bar]
    end

    it "should find with trailing #" do
      EXb.bar.qname.should == [:exb, :bar]
    end

    it "should find with trailing word" do
      EXc.bar.qname.should == [:exc, :bar]
    end
  end
end
