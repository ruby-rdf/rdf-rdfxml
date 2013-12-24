$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/writer'
autoload :CGI, 'cgi'

class FOO < RDF::Vocabulary("http://foo/"); end

describe "RDF::RDFXML::Writer" do
  before(:each) do
    @graph = RDF::Repository.new
    @writer = RDF::RDFXML::Writer.new(StringIO.new)
    @writer_class = RDF::RDFXML::Writer
  end
  
  include RDF_Writer
  
  describe "#buffer" do
    context "typed resources" do
      context "resource without type" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
          serialize(:attributes => :untyped)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      context "resource with type" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
          serialize(:attributes => :untyped)
        end

        {
          "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
          "/rdf:RDF/foo:Release/@dc:title" =>"foo",
          "/rdf:RDF/foo:Release/rdf:type" => false
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      context "resource with two types as attribute" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
          @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.XtraRelease]
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
          serialize(:attributes => :untyped)
        end

        {
          "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
          "/rdf:RDF/foo:Release/@dc:title" => "foo",
          "/rdf:RDF/foo:Release/rdf:type/@rdf:resource" => FOO.XtraRelease.to_s
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
    
      context "resource with two types as element" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
          @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.XtraRelease]
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
          serialize(:attributes => :none)
        end

        {
          "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
          "/rdf:RDF/foo:Release/dc:title/text()" => "foo",
          %(/rdf:RDF/foo:Release/rdf:type/@rdf:resource) => FOO.XtraRelease.to_s,
          %(/rdf:RDF/foo:Release/rdf:type[@rdf:resource="#{FOO.Release}"]) => false
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
    
      context "resource with three types as element" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
          @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.XtraRelease]
          @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.XXtraRelease]
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
          serialize(:attributes => :typed)
        end

        {
          "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
          "/rdf:RDF/foo:Release/@dc:title" => "foo",
          %(/rdf:RDF/foo:Release/rdf:type[@rdf:resource="#{FOO.XtraRelease}"]) => %r(#{FOO.XtraRelease}),
          %(/rdf:RDF/foo:Release/rdf:type[@rdf:resource="#{FOO.XXtraRelease}"]) => %r(#{FOO.XXtraRelease})
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
    end
  
    context "with children" do
      subject do
        @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
        @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
        @graph << [RDF::URI.new("http://release/contributor"), RDF.type, FOO.Contributor]
        @graph << [RDF::URI.new("http://release/contributor"), RDF::DC.title, "bar"]
        @graph << [RDF::URI.new("http://release/"), FOO.releaseContributor, RDF::URI.new("http://release/contributor")]
        serialize(:attributes => :untyped)
      end

      {
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" => "foo",
        "/rdf:RDF/foo:Release/foo:releaseContributor/foo:Contributor/@rdf:about" => "http://release/contributor"
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, {}, @debug)
        end
      end
    end
  
    context "with sequences" do
      context "rdf:Seq with rdf:_n" do
        subject do
          @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Seq]
          @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
          @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
          serialize
        end

        {
          "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Seq/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Seq/rdf:_2[@rdf:resource="http://example/second"]) => /second/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      context "rdf:Seq with rdf:_n in proper sequence" do
        subject do
          @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Seq]
          @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
          @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
          serialize
        end

        {
          "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Seq/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Seq/rdf:_2[@rdf:resource="http://example/second"]) => /secon/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end

      context "rdf:Bag with rdf:_n" do
        subject do
          @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Bag]
          @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
          @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
          serialize
        end

        {
          "/rdf:RDF/rdf:Bag/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Bag/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Bag/rdf:_2[@rdf:resource="http://example/second"]) => /secon/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end

      context "rdf:Alt with rdf:_n" do
        subject do
          @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Alt]
          @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
          @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
          serialize
        end

        {
          "/rdf:RDF/rdf:Alt/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Alt/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Alt/rdf:_2[@rdf:resource="http://example/second"]) => /secon/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
    end

    describe "with lists" do
      context "List rdf:first/rdf:rest" do
        {
          %q(<author> <is> (:Gregg :Barnum :Kellogg) .) => {
            "/rdf:RDF/rdf:Description/@rdf:about" => "http://foo/author",
            "/rdf:RDF/rdf:Description/foo:is/@rdf:parseType" => "Collection",
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/Gregg"]) => /Gregg/,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/Barnum"]) => /Barnum/,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/Kellogg"]) => /Kellogg/,
            %(//rdf:first)  => false
          },
          %q(<author> <is> (_:Gregg _:Barnum _:Kellogg) .) => {
            "/rdf:RDF/rdf:Description/@rdf:about" => "http://foo/author",
            "/rdf:RDF/rdf:Description/foo:is/@rdf:parseType" => "Collection",
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[1]) => /Desc/,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[2]) => /Desc/,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[3]) => /Desc/,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[1]/@rdf:nodeID) => false,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[2]/@rdf:nodeID) => false,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[3]/@rdf:nodeID) => false,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[4]) => false,
            %(//rdf:first)  => false
          },
          %q(<author> <is> (_:Gregg _:Barnum _:Kellogg); <and> _:Gregg, _:Barnum, _:Kellogg .) => {
            "/rdf:RDF/rdf:Description/@rdf:about" => "http://foo/author",
            "/rdf:RDF/rdf:Description/foo:is/@rdf:parseType" => "Collection",
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[1]) => /Desc/,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[2]) => /Desc/,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[3]) => /Desc/,
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[1]/@rdf:nodeID) => "Gregg",
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[2]/@rdf:nodeID) => "Barnum",
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[3]/@rdf:nodeID) => "Kellogg",
            %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[4]) => false,
            %(//rdf:first)  => false
          },
          %q(<author> <is> ("Gregg" "Barnum" "Kellogg") .) => {
            "/rdf:RDF/rdf:Description/@rdf:about" => "http://foo/author",
            "/rdf:RDF/rdf:Description/foo:is/@rdf:parseType" => false,
            %(//rdf:first)  => /Gregg/
          },
        }.each do |ttl, match|
          context ttl do
            subject do
              @graph = parse(ttl, :base_uri => "http://foo/", :reader => RDF::Turtle::Reader)
              serialize({})
            end
            match.each do |path, value|
              it "returns #{value.inspect} for xpath #{path}" do
                subject.should have_xpath(path, value, {}, @debug)
              end
            end
          end
        end
      end
  
      context "resource with rdf:_n in proper sequence" do
        subject do
          @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Seq]
          @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
          @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
          serialize
        end

        {
          "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Seq/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Seq/rdf:_2[@rdf:resource="http://example/second"]) => /second/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
    end

    context "with untyped literals" do
      context ":attributes == :none" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
          serialize(:attributes => :none)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title/text()" => "foo"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      [:untyped, :typed].each do |opt|
        context ":attributes == #{opt}" do
          subject do
            @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
            serialize(:attributes => opt)
          end

          {
            "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
            "/rdf:RDF/rdf:Description/@dc:title" => "foo"
          }.each do |path, value|
            it "returns #{value.inspect} for xpath #{path}" do
              subject.should have_xpath(path, value, {}, @debug)
            end
          end
        end
      end
  
      context "untyped without lang if attribute lang set" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
          serialize(:attributes => :untyped, :lang => "de")
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end

      context "with language" do
        context "property for title" do
          subject do
            @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "en-us")]
            serialize(:attributes => :untyped, :lang => "de")
          end

          {
            "/rdf:RDF/@xml:lang" => "de",
            "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
            "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="en-us">foo</dc:title>)
          }.each do |path, value|
            it "returns #{value.inspect} for xpath #{path}" do
              subject.should have_xpath(path, value, {}, @debug)
            end
          end
        end
      end
  
      context "attribute if lang is default" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
          serialize(:attributes => :untyped, :lang => "de")
        end

        {
          "/rdf:RDF/@xml:lang" => "de",
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      context "untyped as property if lang set and no default" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
          serialize(:attributes => :untyped)
        end

        {
          "/rdf:RDF/@xml:lang" => false,
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="de">foo</dc:title>)
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      context "untyped as property if lang set and not default" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
          serialize(:attributes => :untyped, :lang => "en-us")
        end

        {
          "/rdf:RDF/@xml:lang" => "en-us",
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="de">foo</dc:title>)
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {})
          end
        end
      end
  
      context "multiple untyped attributes values through properties" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "en-us")]
          serialize(:attributes => :untyped, :lang => "en-us")
        end

        {
          "/rdf:RDF/@xml:lang" => "en-us",
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="de">foo</dc:title>)
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      context "typed node as element if :untyped" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :datatype => RDF::XSD.string)]
          serialize(:attributes => :untyped)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => %(foo)
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      context "typed node as attribute if :typed" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :datatype => RDF::XSD.string)]
          serialize(:attributes => :typed)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
  
      context "multiple typed values through properties" do
        subject do
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :datatype => RDF::XSD.string)]
          @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("bar", :datatype => RDF::XSD.string)]
          serialize(:attributes => :untyped)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title[contains(., 'foo')]" => %(<dc:title>foo</dc:title>),
          "/rdf:RDF/rdf:Description/dc:title[contains(., 'bar')]" => %(<dc:title>bar</dc:title>)
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
    end

    context "with namespace" do
      before(:each) do
        @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
        @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
        @graph << [RDF::URI.new("http://release/"), FOO.pred, FOO.obj]
      end

      context "default namespace" do
        subject do
          serialize(:default_namespace => FOO.to_s,
                    :prefixes => {:foo => FOO.to_s})
        end

        {
          "/rdf:RDF/foo:Release/foo:pred/@rdf:resource" => FOO.obj.to_s,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {"foo" => FOO.to_s}, @debug)
          end
        end

        specify { subject.should =~ /<Release/ }
        specify { subject.should =~ /<pred/ }
      end

      context "nil namespace" do
        subject do
          serialize(:prefixes => {nil => FOO.to_s})
        end

        {
          "/rdf:RDF/foo:Release/foo:pred/@rdf:resource" => FOO.obj.to_s,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {"foo" => FOO.to_s}, @debug)
          end
        end

        specify { subject.should =~ /<Release/ }
        specify { subject.should =~ /<pred/ }
      end
    end
  
    describe "with base" do
      context "relative about URI" do
        subject do
          @graph << [RDF::URI.new("http://release/a"), FOO.ref, RDF::URI.new("http://release/b")]
          serialize(:attributes => :untyped, :base_uri => "http://release/")
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "a",
          "/rdf:RDF/rdf:Description/foo:ref/@rdf:resource" => "b"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
    end
  
    context "with bnodes" do
      context "no nodeID attribute unless node is referenced as an object" do
        subject do
          @graph << [RDF::Node.new("a"), RDF::DC.title, "foo"]
          serialize(:attributes => :untyped, :base_uri => "http://release/")
        end

        {
          "/rdf:RDF/rdf:Description/@dc:title" => "foo",
          "/rdf:RDF/rdf:Description/@rdf:nodeID" => false
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end

      context "nodeID attribute if node is referenced as an object" do
        subject do
          bn = RDF::Node.new("a")
          @graph << [bn, RDF::DC.title, "foo"]
          @graph << [bn, RDF::OWL.sameAs, bn]
          serialize(:attributes => :untyped, :base_uri => "http://release/")
        end

        {
          "/rdf:RDF/rdf:Description/@dc:title" => "foo",
          "/rdf:RDF/rdf:Description/@rdf:nodeID" => /a$/,
          "/rdf:RDF/rdf:Description/owl:sameAs/@rdf:nodeID" => /a$/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, {}, @debug)
          end
        end
      end
      
      context "rdf:nodeID for forced BNode generation" do
        subject do
          @graph = parse(%(
            @prefix : <http://example/> .
            :foo :list (:bar (:baz)).
          ))
          serialize
        end

        specify { parse(subject).should be_equivalent_graph(@graph, :trace => @debug.unshift(subject).join("\n")) }
      end
    
      it "should not generate extraneous BNode" do
        @graph = parse(%(
          @prefix owl: <http://www.w3.org/2002/07/owl#> .
          <part_of> a owl:ObjectProperty .
          <a> a owl:Class .
          <b> a owl:Class .
          [ a owl:Class;
            owl:intersectionOf (
              <b>
              [ a owl:Class, owl:Restriction;
                owl:onProperty <part_of>;
                owl:someValuesFrom <a>]
            )
          ] .
          [ a owl:Class; owl:intersectionOf (<a> <b>)] .
        ), :reader => RDF::Turtle::Reader)
        doc = serialize
        @debug.unshift(doc)
        parse(doc).should be_equivalent_graph(@graph, :trace => @debug.join("\n"))
      end
    end

    describe "with a stylesheet" do
      subject do
        @graph << [RDF::URI.new("http://release/a"), FOO.ref, RDF::URI.new("http://release/b")]
        serialize(:stylesheet => "/path/to/rdfxml.xsl")
      end

      it "should have a stylesheet as a processing instruction in the second line of the XML" do
        lines = subject.split(/[\r\n]+/)
        lines[1].should == '<?xml-stylesheet type="text/xsl" href="/path/to/rdfxml.xsl"?>'
      end
    end
  
    describe "illegal RDF values" do
      it "raises error with literal as subject" do
        @graph << [RDF::Literal.new("literal"), RDF::DC.title, RDF::Literal.new("foo")]
        expect { serialize(:validate => true) }.to raise_error(RDF::WriterError)
      end
      it "raises error with node as predicate" do
        @graph << [RDF::URI("http://example.com"), RDF::Node.new, RDF::Literal.new("foo")]
        expect { serialize(:validate => true) }.to raise_error(RDF::WriterError)
      end
    end

    # W3C RDF/XML Test suite from https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-xml/tests/
    describe "w3c RDF/XML tests" do
      require 'suite_helper'
      %w(manifest.ttl).each do |man|
        Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |m|
          describe m.comment do
            m.entries.each do |t|
              next unless t.positive_test? && t.evaluate?
              # Literal serialization adds namespace definitions
              next if t.subject =~ /rdfms-xml-literal-namespaces|xml-canon/

              specify "#{t.name}" do
                @graph = parse(t.expected, :base_uri => t.base, :format => :ntriples)

                serialized = serialize(:format => :rdfxml, :base_uri => t.base)
                # New RBX failure :(
                trace = @debug.unshift(serialized).map do |s|
                  s.force_encoding(Encoding::UTF_8)
                end.join("\n")
                expect(parse(serialized, :base_uri => t.base)).to be_equivalent_graph(@graph, :trace => trace)
              end
            end
          end
        end
      end
    end unless ENV['CI'] # Not for continuous integration

    def check_xpaths(doc, paths)
      puts doc.to_s if ::RDF::RDFXML::debug? || $verbose
      doc = Nokogiri::XML.parse(doc)
      doc.should be_a(Nokogiri::XML::Document)
      doc.root.should be_a(Nokogiri::XML::Element)
      paths.each_pair do |path, value|
        next if path.is_a?(Symbol)
        @debug <<  doc.root.at_xpath(path, doc.namespaces).to_s if ::RDF::RDFXML::debug?
        case value
        when false
          doc.root.at_xpath(path, doc.namespaces).should be_nil
        when true
          doc.root.at_xpath(path, doc.namespaces).should_not be_nil
        when Array
          doc.root.at_xpath(path, doc.namespaces).to_s.split(" ").should include(*value)
        when Regexp
          doc.root.at_xpath(path, doc.namespaces).to_s.should =~ value
        else
          doc.root.at_xpath(path, doc.namespaces).to_s.should == value
        end
      end
    
      # Parse generated graph and compare to source
      if paths[:reparse]
        graph = RDF::Repository.new
        RDF::RDFXML::Reader.new(doc, :base_uri => "http://release/", :format => :rdfxml).each {|st| graph << st}
        graph.should be_equivalent_graph(@graph, :about => "http://release/", :trace => @debug.join("\n"))
      end
    end

    def parse(input, options = {})
      reader_class = options.fetch(:reader, RDF::Reader.for(detect_format(input)))
    
      graph = RDF::Graph.new
      reader_class.new(input, options).each do |statement|
        graph << statement
      end
      graph
    end

    # Serialize  @graph to a string and compare against regexps
    def serialize(options = {})
      @debug = []
      result = @writer_class.buffer({:debug => @debug, :standard_prefixes => true}.merge(options)) do |writer|
        writer << @graph
      end
      require 'cgi'
      puts CGI.escapeHTML(result) if $verbose
      result
    end
  end
end