require File.join(File.dirname(__FILE__), 'spec_helper')

FOO = RDF::Vocabulary.new("http://foo/")

describe "RDF::RDFXML::Writer" do
  before(:each) do
    @graph = RDF::Graph.new
  end
  
  describe "with types" do
    it "should serialize resource without type" do
      @graph << ["http://release/", RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end
  
    it "should serialize resource with type" do
      @graph << ["http://release/", RDF.type, FOO.Release]
      @graph << ["http://release/", RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" =>"foo",
        "/rdf:RDF/foo:Release/rdf:type" => ""
      )
    end
  
    it "should serialize resource with two types as attribute" do
      @graph << ["http://release/", RDF.type, FOO.Release]
      @graph << ["http://release/", RDF.type, FOO.XtraRelease]
      @graph << ["http://release/", RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" => "foo",
        "/rdf:RDF/foo:Release/@rdf:type" => FOO.XtraRelease.to_s
      )
    end
    
    it "should serialize resource with two types as element" do
      @graph << ["http://release/", RDF.type, FOO.Release]
      @graph << ["http://release/", RDF.type, FOO.XtraRelease]
      @graph << ["http://release/", RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :none),
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/dc:title" => true,
        "/rdf:RDF/foo:Release/rdf:type" => %(<rdf:type rdf:resource="#{FOO.XtraRelease}"/>)
      )
    end
    
    it "should serialize resource with three types as element" do
      @graph << ["http://release/", RDF.type, FOO.Release]
      @graph << ["http://release/", RDF.type, FOO.XtraRelease]
      @graph << ["http://release/", RDF.type, FOO.XXtraRelease]
      @graph << ["http://release/", RDF::DC.title, "foo"]
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
      @graph << ["http://release/", RDF.type, FOO.Release]
      @graph << ["http://release/", RDF::DC.title, "foo"]
      @graph << ["http://release/contributor", RDF.type, FOO.Contributor]
      @graph << ["http://release/contributor", RDF::DC.title, "bar"]
      @graph << ["http://release/", FOO.releaseContributor, "http://release/contributor"]
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
      @graph << ["http://release/", RDF.type, FOO.Release]
      @graph << ["http://release/", RDF::DC.title, "foo"]
      @graph << ["http://release/contributor", RDF.type, FOO.Contributor]
      @graph << ["http://release/contributor", RDF::DC.title, "bar"]
      @graph << ["http://release/", FOO.releaseContributor, "http://release/contributor"]
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
      @graph << ["http://example/seq", RDF.type, RDF.Seq]
      @graph << ["http://example/seq", RDF._1, "http://example/first"]
      @graph << ["http://example/seq", RDF._2, "http://example/second"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end
  
    it "should serialize rdf:Seq with multiple rdf:li in proper sequence" do
      @graph << ["http://example/seq", RDF.type, RDF.Seq]
      @graph << ["http://example/seq", RDF._2, "http://example/second"]
      @graph << ["http://example/seq", RDF._1, "http://example/first"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Seq/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end

    it "should serialize rdf:Bag with multiple rdf:li" do
      @graph << ["http://example/seq", RDF.type, RDF.Bag]
      @graph << ["http://example/seq", RDF._2, "http://example/second"]
      @graph << ["http://example/seq", RDF._1, "http://example/first"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Bag/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Bag/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Bag/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end

    it "should serialize rdf:Alt with multiple rdf:li" do
      @graph << ["http://example/seq", RDF.type, RDF.Alt]
      @graph << ["http://example/seq", RDF._2, "http://example/second"]
      @graph << ["http://example/seq", RDF._1, "http://example/first"]
      check_xpaths(
        serialize(:max_depth => 1, :attributes => :untyped),
        "/rdf:RDF/rdf:Alt/@rdf:about" => "http://example/seq",
        %(/rdf:RDF/rdf:Alt/rdf:li[@rdf:resource="http://example/first"]) => true,
        %(/rdf:RDF/rdf:Alt/rdf:li[@rdf:resource="http://example/second"]) => true
      )
    end
  end

  describe "with lists" do
    it "should serialize List rdf:first/rdf:rest" do
      @graph.parse(%(@prefix foo: <http://foo/> . foo:author foo:is (Gregg Barnum Kellogg).), "http://foo/", :type => :ttl)
      check_xpaths(
        serialize({}),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://foo/author",
        "/rdf:RDF/rdf:Description/foo:is/@rdf:parseType" => "Collection",
        %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/#Gregg"]) => true,
        %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/#Barnum"]) => true,
        %(/rdf:RDF/rdf:Description/foo:is/rdf:Description[@rdf:about="http://foo/#Kellogg"]) => true,
        %(//rdf:first)  => false
      )
    end
  
    it "should serialize resource with multiple rdf:li in proper sequence" do
      @graph << ["http://example/seq", RDF.type, RDF.Seq]
      @graph << ["http://example/seq", RDF._2, "http://example/second"]
      @graph << ["http://example/seq", RDF._1, "http://example/first"]
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
      @graph << ["http://release/", RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:attributes => :none),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title" => "<dc:title>foo</dc:title>"
      )
    end
  
    it "should seralize as attribute if :attributes == :untyped or :typed" do
      @graph << ["http://release/", RDF::DC.title, "foo"]
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

    it "should output untyped without lang as attribute lang set" do
      @graph << ["http://release/", RDF::DC.title, "foo"]
      check_xpaths(
        serialize(:attributes => :untyped, :lang => "de"),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end

    describe "with language" do
      it "should output property for title with language" do
        @graph << ["http://release/", RDF::DC.title, Literal.untyped("foo", "en-us")]
        check_xpaths(
          serialize(:attributes => :untyped, :lang => "de"),
          "/rdf:RDF/@xml:lang" => "de",
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="en-us">foo</dc:title>)
        )
      end
    end
  
    it "should output untyped as attribute if lang is default" do
      @graph << ["http://release/", RDF::DC.title, Literal.untyped("foo", "de")]
      check_xpaths(
        serialize(:attributes => :untyped, :lang => "de"),
        "/rdf:RDF/@xml:lang" => "de",
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end
  
    it "should output untyped as property if lang set and no default" do
      @graph << ["http://release/", RDF::DC.title, Literal.untyped("foo", "de")]
      check_xpaths(
        serialize(:attributes => :untyped),
        "/rdf:RDF/@xml:lang" => false,
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="de">foo</dc:title>)
      )
    end
  
    it "should output untyped as property if lang set and not default" do
      @graph << ["http://release/", RDF::DC.title, Literal.untyped("foo", "de")]
      check_xpaths(
        serialize(:attributes => :untyped, :lang => "en-us"),
        "/rdf:RDF/@xml:lang" => "en-us",
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title xml:lang="de">foo</dc:title>)
      )
    end
  
    it "should output multiple untyped attributes values through properties" do
      @graph << ["http://release/", RDF::DC.title, Literal.untyped("foo", "de")]
      @graph << ["http://release/", RDF::DC.title, Literal.untyped("foo", "en-us")]
      check_xpaths(
        serialize(:attributes => :untyped, :lang => "en-us"),
        "/rdf:RDF/@xml:lang" => "en-us",
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title[lang('de')]" => %(<dc:title xml:lang="de">foo</dc:title>),
        "/rdf:RDF/rdf:Description/dc:title[lang('en-us')]" => %(<dc:title>foo</dc:title>)
      )
    end
  
    it "should output typed node as attribute" do
      @graph << ["http://release/", RDF::DC.title, Literal.typed("foo", XSD.string)]
      check_xpaths(
        serialize(:attributes => :untyped),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/dc:title" => %(<dc:title rdf:datatype="#{XSD.string}">foo</dc:title>)
      )
      check_xpaths(
        serialize(:attributes => :typed),
        "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
        "/rdf:RDF/rdf:Description/@dc:title" => "foo"
      )
    end
  
    it "should output multiple typed values through properties" do
      @graph << ["http://release/", RDF::DC.title, Literal.typed("foo", XSD.string)]
      @graph << ["http://release/", RDF::DC.title, Literal.typed("bar", XSD.string)]
        check_xpaths(
          serialize(:attributes => :untyped),
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title[contains(., 'foo')]" => %(<dc:title rdf:datatype="#{XSD.string}">foo</dc:title>),
          "/rdf:RDF/rdf:Description/dc:title[contains(., 'bar')]" => %(<dc:title rdf:datatype="#{XSD.string}">bar</dc:title>)
        )
    end
  end
  
  describe "with default namespace" do
    it "should serialize with default namespace" do
      @graph << ["http://release/", RDF.type, FOO.Release]
      @graph << ["http://release/", RDF::DC.title, "foo"]
      @graph << ["http://release/", FOO.pred, FOO.obj]
      @graph.bind(Namespace.new(FOO.uri, ""))
    
      #$DEBUG = true
      xml = serialize(:max_depth => 1, :attributes => :untyped)
      #puts xml
      xml.should =~ /<Release/
      xml.should =~ /<pred/
      doc = Nokogiri::XML.parse(xml)
      doc.at_xpath("/rdf:RDF/#{FOO.prefix}:Release/#{FOO.prefix}:pred/@rdf:resource", doc.namespaces).to_s.should == FOO.obj.to_s
    end
  end
  
  describe "with base" do
    it "should generate relative about URI" do
      @graph << ["http://release/a", FOO.ref, "http://release/b"]
        check_xpaths(
          serialize(:attributes => :untyped, :base => "http://release/"),
          "/rdf:RDF/rdf:Description/@rdf:about" => "a",
          "/rdf:RDF/rdf:Description/foo:ref/@rdf:resource" => "b"
        )
    end
  end
  
  describe "with bnodes" do
    it "should not generate nodeID attribute unless node is referenced as an object" do
      @graph << [BNode.new("a"), RDF::DC.title, "foo"]
        check_xpaths(
          serialize(:attributes => :untyped, :base => "http://release/"),
          "/rdf:RDF/rdf:Description/@dc:title" => "foo",
          "/rdf:RDF/rdf:Description/@rdf:nodeID" => false
        )
    end
    
    it "should generate a nodeID attribute if node is referenced as an object" do
      bn = BNode.new("a")
      @graph << [bn, RDF::DC.title, "foo"]
      @graph << [bn, OWL.equals, bn]
      check_xpaths(
        serialize(:attributes => :untyped, :base => "http://release/"),
        "/rdf:RDF/rdf:Description/@dc:title" => "foo",
        "/rdf:RDF/rdf:Description/@rdf:nodeID" => /Na$/,
        "/rdf:RDF/rdf:Description/owl:equals/@rdf:nodeID" => /Na$/
      )
    end
    
    it "should replicate rdfcore/rdfms-seq-representation" do
      @graph.parse(%(
        <http://example.org/eg#eric> a [ <http://example.org/eg#intersectionOf> (<http://example.org/eg#Person> <http://example.org/eg#Male>)] .
      ))
      graph2 = Graph.new
      graph2.parse(serialize(:format => :xml)).should be_equivalent_graph(@graph)
    end
  end
  
  def check_xpaths(doc, paths)
    puts doc if $DEBUG || $verbose
    doc = Nokogiri::XML.parse(doc)
    #puts "doc: #{doc.to_s}"
    doc.should be_a(Nokogiri::XML::Document)
    paths.each_pair do |path, value|
      puts "xpath: #{path.inspect}" if $DEBUG
      puts doc.root.at_xpath(path, @namespaces).inspect if $DEBUG
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
    Graph.load(doc, :base_uri => "http://release/", :format => :rdf).should
      be_equivalent_graph(@graph, :about => "http://release/")
  end
  
  # Serialize ntstr to a string and compare against regexps
  def serialize(options)
    result = RDF::RDFXML::Writer.buffer(options) do |writer|
      writer.write_graph(@graph)
    end
    result
  end
end