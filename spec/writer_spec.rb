$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/writer'
autoload :CGI, 'cgi'

class FOO < RDF::Vocabulary("http://foo/"); end

describe "RDF::RDFXML::Writer" do
  before(:each) do
    @graph = RDF::Graph.new
    @writer = RDF::RDFXML::Writer
  end
  
  it_should_behave_like RDF_Writer
  
  describe "with types" do
    it "should serialize resource without type" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end
  
    it "should serialize resource with type" do
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" =>"foo",
        "/rdf:RDF/foo:Release/rdf:type" => ""
      )
    end
  
    it "should serialize resource with two types as attribute" do
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.XtraRelease]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" => "foo",
        "/rdf:RDF/foo:Release/@rdf:type" => FOO.XtraRelease.to_s
      )
    end
    
    it "should serialize resource with two types as element" do
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.XtraRelease]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :none),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/dc:title" => true,
        "/rdf:RDF/foo:Release/rdf:type" => %(<rdf:type rdf:resource="#{FOO.XtraRelease}"/>)
      )
    end
    
    it "should serialize resource with three types as element" do
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.XtraRelease]
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.XXtraRelease]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :typed),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" => true,
        %(/rdf:RDF/foo:Release/rdf:type[@rdf:resource="#{FOO.XtraRelease}"]) => true,
        %(/rdf:RDF/foo:Release/rdf:type[@rdf:resource="#{FOO.XXtraRelease}"]) => true
      )
    end
  end
  
  describe "with children" do
    it "should serialize referenced resource by ref" do
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      @graph << [RDF::URI.new("http://release/contributor"), RDF.type, FOO.Contributor]
      @graph << [RDF::URI.new("http://release/contributor"), RDF::DC.title, "bar"]
      @graph << [RDF::URI.new("http://release/"), FOO.releaseContributor, RDF::URI.new("http://release/contributor")]
        check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" => "foo",
        "/rdf:RDF/foo:Release/foo:releaseContributor/@rdf:resource" => "http://release/contributor",
        "/rdf:RDF/foo:Contributor/@rdf:about" => "http://release/contributor",
        "/rdf:RDF/foo:Contributor/@dc:title" => "bar"
      )
    end
  
    it "should serialize referenced resource by inclusion" do
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      @graph << [RDF::URI.new("http://release/contributor"), RDF.type, FOO.Contributor]
      @graph << [RDF::URI.new("http://release/contributor"), RDF::DC.title, "bar"]
      @graph << [RDF::URI.new("http://release/"), FOO.releaseContributor, RDF::URI.new("http://release/contributor")]
      check_xpaths(
        serialize(:max_depth => 3, :attributes => :untyped),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" => "foo",
        "/rdf:RDF/foo:Release/foo:releaseContributor/foo:Contributor/@rdf:about" => "http://release/contributor"
      )
    end
  end
  
  describe "with sequences" do
    it "should serialize rdf:Seq with rdf:li" do
      @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Seq]
      @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
      @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end
  
    it "should serialize rdf:Seq with multiple rdf:li in proper sequence" do
      @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Seq]
      @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
      @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end

    it "should serialize rdf:Bag with multiple rdf:li" do
      @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Bag]
      @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
      @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Bag/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Bag/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Bag/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end

    it "should serialize rdf:Alt with multiple rdf:li" do
      @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Alt]
      @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
      @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Alt/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Alt/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Alt/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end
  end

  describe "with lists" do
#    it "should serialize List rdf:first/rdf:rest" do
#      @graph.parse(%(@prefix foo: <http://foo/> . foo:author foo:is (Gregg Barnum Kellogg).), "http://foo/", :type => :ttl)
#      check_xpaths(
#        serialize({}),
#        "/rdf:RDF/rdf:Description/@rdf:about" => "http://foo/author",
#        "/rdf:RDF/rdf:Description/foo:is/@rdf:parseType" => "Collection",
#        %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/#Gregg"]) => true,
#        %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/#Barnum"]) => true,
#        %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/#Kellogg"]) => true,
#        %(//rdf:first)  => false
#      )
#    end
  
    it "should serialize resource with multiple rdf:li in proper sequence" do
      @graph << [RDF::URI.new("http://example/seq"), RDF.type, RDF.Seq]
      @graph << [RDF::URI.new("http://example/seq"), RDF._2, RDF::URI.new("http://example/second")]
      @graph << [RDF::URI.new("http://example/seq"), RDF._1, RDF::URI.new("http://example/first")]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end
  end

  describe "with untyped literals" do
    it "should seralize as element if :attributes == :none" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:attributes => :none),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title" => "<dc:title>foo</dc:title>"
      )
    end
  
    it "should seralize as attribute if :attributes == :untyped or :typed" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:attributes => :untyped),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
      check_xpaths(
        serialize(:attributes => :typed),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end

    it "should output untyped without lang if attribute lang set" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
      check_xpaths(
        serialize(:attributes => :untyped, :lang => "de"),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end

    describe "with language" do
      it "should output property for title with language" do
        @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "en-us")]
        check_xpaths(
          serialize(:attributes => :untyped, :lang => "de"),
          "/rdf:RDF/@xml:lang" => "de",
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="en-us">foo</dc:title>)
        )
      end
    end
  
    it "should output untyped as attribute if lang is default" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
      check_xpaths(
        serialize(:attributes => :untyped, :lang => "de"),
        "/rdf:RDF/@xml:lang" => "de",
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end
  
    it "should output untyped as property if lang set and no default" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
      check_xpaths(
        serialize(:attributes => :untyped),
        "/rdf:RDF/@xml:lang" => false,
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="de">foo</dc:title>)
      )
    end
  
    it "should output untyped as property if lang set and not default" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
      check_xpaths(
        serialize(:attributes => :untyped, :lang => "en-us"),
        "/rdf:RDF/@xml:lang" => "en-us",
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="de">foo</dc:title>)
      )
    end
  
    it "should output multiple untyped attributes values through properties" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "de")]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :language => "en-us")]
      check_xpaths(
        serialize(:attributes => :untyped, :lang => "en-us"),
        "/rdf:RDF/@xml:lang" => "en-us",
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title[lang('de')]" => %(<dc:title xml:lang="de">foo</dc:title>),
        "/rdf:RDF/rdf:Description/dc:title[lang('en-us')]" => %(<dc:title>foo</dc:title>)
      )
    end
  
    it "should output typed node as attribute" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :datatype => RDF::XSD.string)]
      check_xpaths(
        serialize(:attributes => :untyped),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title rdf:datatype="#{RDF::XSD.string}">foo</dc:title>)
      )
      check_xpaths(
        serialize(:attributes => :typed),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end
  
    it "should output multiple typed values through properties" do
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("foo", :datatype => RDF::XSD.string)]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, RDF::Literal.new("bar", :datatype => RDF::XSD.string)]
        check_xpaths(
          serialize(:attributes => :untyped),
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title[contains(., 'foo')]" => %(<dc:title rdf:datatype="#{RDF::XSD.string}">foo</dc:title>),
          "/rdf:RDF/rdf:Description/dc:title[contains(., 'bar')]" => %(<dc:title rdf:datatype="#{RDF::XSD.string}">bar</dc:title>)
        )
    end
  end

  describe "with default namespace" do
    it "should serialize with default namespace" do
      @graph << [RDF::URI.new("http://release/"), RDF.type, FOO.Release]
      @graph << [RDF::URI.new("http://release/"), RDF::DC.title, "foo"]
      @graph << [RDF::URI.new("http://release/"), FOO.pred, FOO.obj]
    
      xml = serialize(:max_depth => 1, :attributes => :untyped, :default_namespace => FOO.to_s)
      xml.should =~ /<Release/
      xml.should =~ /<pred/
      doc = Nokogiri::XML.parse(xml)
      doc.at_xpath("/rdf:RDF/foo:Release/foo:pred/@rdf:resource", doc.namespaces).to_s.should == FOO.obj.to_s
    end
  end
  
  describe "with base" do
    it "should generate relative about URI" do
      @graph << [RDF::URI.new("http://release/a"), FOO.ref, RDF::URI.new("http://release/b")]
      check_xpaths(
        serialize(:attributes => :untyped, :base_uri => "http://release/"),
        "/rdf:RDF/rdf:Description/@rdf:about" => "a",
        "/rdf:RDF/rdf:Description/foo:ref/@rdf:resource" => "b"
      )
    end
  end
  
  describe "with bnodes" do
    it "should not generate nodeID attribute unless node is referenced as an object" do
      @graph << [RDF::Node.new("a"), RDF::DC.title, "foo"]
        check_xpaths(
          serialize(:attributes => :untyped, :base => "http://release/"),
          "/rdf:RDF/rdf:Description/@dc:title" => "foo",
          "/rdf:RDF/rdf:Description/@rdf:nodeID" => false
        )
    end
    
    it "should generate a nodeID attribute if node is referenced as an object" do
      bn = RDF::Node.new("a")
      @graph << [bn, RDF::DC.title, "foo"]
      @graph << [bn, RDF::OWL.equals, bn]
      check_xpaths(
        serialize(:attributes => :untyped, :base => "http://release/"),
        "/rdf:RDF/rdf:Description/@dc:title" => "foo",
        "/rdf:RDF/rdf:Description/@rdf:nodeID" => /a$/,
        "/rdf:RDF/rdf:Description/owl:equals/@rdf:nodeID" => /a$/
      )
    end
    
    it "should replicate rdfcore/rdfms-seq-representation" do
      begin
        @graph.parse(%(
          <http://example.org/eg#eric> a [ <http://example.org/eg#intersectionOf> (<http://example.org/eg#Person> <http://example.org/eg#Male>)] .
        ))
        graph2 = Graph.new
        graph2.parse(serialize(:format => :xml)).should be_equivalent_graph(@graph, :trace => @debug.join("\n"))
      rescue
        pending("Requires Turtle reader")
      end
    end
  end
  
  def check_xpaths(doc, paths)
    puts doc.to_s if $DEBUG || $verbose
    doc = Nokogiri::XML.parse(doc)
    doc.should be_a(Nokogiri::XML::Document)
    doc.root.should be_a(Nokogiri::XML::Element)
    paths.each_pair do |path, value|
      @debug <<  doc.root.at_xpath(path, @namespaces).to_s if $DEBUG
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
    #graph = RDF::Graph.new
    #RDF::RDFXML::Reader.new(doc, :base_uri => "http://release/", :format => :rdf).each {|st| graph << st}
    #graph.should be_equivalent_graph(@graph, :about => "http://release/", :trace => @debug.join("\n"))
  end
  
  # Serialize ntstr to a string and compare against regexps
  def serialize(options = {})
    @debug = []
    result = @writer.buffer(options.merge(:debug => @debug)) do |writer|
      writer << @graph
    end
    puts @debug.join("\n") if $DEBUG
    result
  end
end