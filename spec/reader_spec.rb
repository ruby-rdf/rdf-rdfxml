# coding: utf-8
require File.join(File.dirname(__FILE__), 'spec_helper')

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe "RDF::RDFXML::Reader" do
  context "discovery" do
    {
      "rdf" => RDF::Reader.for(:rdf),
      "xml" => RDF::Reader.for(:xml),
      "etc/foaf.xml" => RDF::Reader.for("etc/foaf.xml"),
      "etc/foaf.rdf" => RDF::Reader.for("etc/foaf.rdf"),
      "foaf.xml" => RDF::Reader.for(:file_name      => "foaf.xml"),
      "foaf.rdf" => RDF::Reader.for(:file_name      => "foaf.xml"),
      ".xml" => RDF::Reader.for(:file_extension => "xml"),
      ".rdf" => RDF::Reader.for(:file_extension => "rdf"),
      "application/xml" => RDF::Reader.for(:content_type   => "application/xml"),
      "application/rdf+xml" => RDF::Reader.for(:content_type   => "application/rdf+xml"),
    }.each_pair do |label, format|
      it "should discover '#{label}'" do
        format.should == RDF::RDFXML::Reader
      end
    end
  end

  context :interface do
    before(:each) do
      @sampledoc = <<-EOF;
<?xml version="1.0" ?>
<GenericXML xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.org/">
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/one">
      <ex:name>Foo</ex:name>
    </rdf:Description>
  </rdf:RDF>
  <blablabla />
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/two">
      <ex:name>Bar</ex:name>
    </rdf:Description>
  </rdf:RDF>
</GenericXML>
EOF
    end
    
    it "should yield reader" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::RDFXML::Reader)
      RDF::RDFXML::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      RDF::RDFXML::Reader.new(@sampledoc).should be_a(RDF::RDFXML::Reader)
    end
    
    it "should yield statements" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::Statement).twice
      RDF::RDFXML::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::URI, RDF::URI, RDF::Literal).twice
      RDF::RDFXML::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end
  
  context "simple parsing" do
    it "should recognise and create single triple for empty non-RDF root" do
      sampledoc = %(<?xml version="1.0" ?>
        <NotRDF />)
      graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      graph.size.should == 1
      statement = graph.statements.first
      statement.subject.class.should == RDF::Node
      statement.predicate.should == RDF.type
      statement.object.should == RDF::XML.NotRDF
    end
  
    it "should parse on XML documents with multiple RDF nodes" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<GenericXML xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.org/">
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/one">
      <ex:name>Foo</ex:name>
    </rdf:Description>
  </rdf:RDF>
  <blablabla />
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/two">
      <ex:name>Bar</ex:name>
    </rdf:Description>
  </rdf:RDF>
</GenericXML>
EOF
      graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      objects = graph.statements.map {|s| s.object.value}.sort
      objects.should == ["Bar", "Foo"]
    end
  
    it "should be able to parse a simple single-triple document" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns:ex="http://www.example.org/" xml:lang="en" xml:base="http://www.example.org/foo">
  <ex:Thing rdf:about="http://example.org/joe" ex:name="bar">
    <ex:belongsTo rdf:resource="http://tommorris.org/" />
    <ex:sampleText rdf:datatype="http://www.w3.org/2001/XMLSchema#string">foo</ex:sampleText>
    <ex:hadADodgyRelationshipWith>
      <rdf:Description>
        <ex:name>Tom</ex:name>
        <ex:hadADodgyRelationshipWith>
          <rdf:Description>
            <ex:name>Rob</ex:name>
            <ex:hadADodgyRelationshipWith>
              <rdf:Description>
                <ex:name>Mary</ex:name>
              </rdf:Description>
            </ex:hadADodgyRelationshipWith>
          </rdf:Description>
        </ex:hadADodgyRelationshipWith>
      </rdf:Description>
    </ex:hadADodgyRelationshipWith>
  </ex:Thing>
</rdf:RDF>
EOF

      graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      #puts @debug
      graph.size.should == 10
      # print graph.to_ntriples
      # TODO: add datatype parsing
      # TODO: make sure the BNode forging is done correctly - an internal element->nodeID mapping
      # TODO: proper test
    end

    it "should be able to handle Bags/Alts etc." do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:eg="http://example.org/">
  <rdf:Bag>
    <rdf:li rdf:resource="http://tommorris.org/" />
    <rdf:li rdf:resource="http://twitter.com/tommorris" />
  </rdf:Bag>
</rdf:RDF>
EOF
      graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      graph.predicates.map(&:to_s).should include("http://www.w3.org/1999/02/22-rdf-syntax-ns#_1", "http://www.w3.org/1999/02/22-rdf-syntax-ns#_2")
    end
  end
  
  context :exceptions do
    it "should raise an error if rdf:aboutEach is used, as per the negative parser test rdfms-abouteach-error001 (rdf:aboutEach attribute)" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:eg="http://example.org/">

  <rdf:Bag rdf:ID="node">
    <rdf:li rdf:resource="http://example.org/node2"/>
  </rdf:Bag>

  <rdf:Description rdf:aboutEach="#node">
    <dc:rights xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:rights>

  </rdf:Description>

</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      end.should raise_error(RDF::ReaderError, /Obsolete attribute .*aboutEach/)
    end

    it "should raise an error if rdf:aboutEachPrefix is used, as per the negative parser test rdfms-abouteach-error002 (rdf:aboutEachPrefix attribute)" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:eg="http://example.org/">

  <rdf:Description rdf:about="http://example.org/node">
    <eg:property>foo</eg:property>
  </rdf:Description>

  <rdf:Description rdf:aboutEachPrefix="http://example.org/">
    <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:creator>

  </rdf:Description>

</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      end.should raise_error(RDF::ReaderError, /Obsolete attribute .*aboutEachPrefix/)
    end

    it "should fail if given a non-ID as an ID (as per rdfcore-rdfms-rdf-id-error001)" do
      sampledoc = <<-EOF;
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
 <rdf:Description rdf:ID='333-555-666' />
</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      end.should raise_error(RDF::ReaderError, /ID addtribute '.*' must be a NCName/)
    end

    it "should make sure that the value of rdf:ID attributes match the XML Name production (child-element version)" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:eg="http://example.org/">
 <rdf:Description>
   <eg:prop rdf:ID="q:name" />
 </rdf:Description>
</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      end.should raise_error(RDF::ReaderError, /ID addtribute '.*' must be a NCName/)
    end

    it "should make sure that the value of rdf:ID attributes match the XML Name production (data attribute version)" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:eg="http://example.org/">
 <rdf:Description rdf:ID="a/b" eg:prop="val" />
</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      end.should raise_error(RDF::ReaderError, "ID addtribute 'a/b' must be a NCName")
    end
  
    it "should detect bad bagIDs" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
 <rdf:Description rdf:bagID='333-555-666' />
</rdf:RDF>
EOF
    
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
        puts @debug
      end.should raise_error(RDF::ReaderError, /Obsolete attribute .*bagID/)
    end
  end
  
  context :reification do
    it "should be able to reify according to §2.17 of RDF/XML Syntax Specification" do
      sampledoc = <<-EOF;
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/stuff/1.0/"
         xml:base="http://example.org/triples/">
  <rdf:Description rdf:about="http://example.org/">
    <ex:prop rdf:ID="triple1">blah</ex:prop>
  </rdf:Description>
</rdf:RDF>
EOF

      triples = <<-EOF
<http://example.org/> <http://example.org/stuff/1.0/prop> \"blah\" .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <http://example.org/> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <http://example.org/stuff/1.0/prop> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> \"blah\" .
EOF

      graph = parse(sampledoc, :base_uri => "http://example.com", :strict => true)
      graph.should be_equivalent_graph(triples, :about => "http://example.com/", :trace => @debug)
    end
  end

  context "parsing rdf files" do
    def test_file(filepath, uri)
      rdf_string = File.read(filepath)
      graph = parse(rdf_string, :base_uri => uri, :strict => true)

      nt_string = File.read(filepath.sub('.rdf', '.nt'))
      nt_graph = RDF::Graph.new
      nt_graph.load(filepath.sub('.rdf', '.nt'))

      graph.should be_equivalent_graph(nt_graph, :about => uri, :trace => @debug)
    end

    before(:all) do
      @rdf_dir = File.join(File.dirname(__FILE__), 'rdf_tests')
    end

    it "should parse Coldplay's BBC Music profile" do
      gid = 'cc197bad-dc9c-440d-a5b5-d52ba2e14234'
      file = File.join(@rdf_dir, "#{gid}.rdf")
      test_file(file, "http://www.bbc.co.uk/music/artists/#{gid}")
    end

    it "should parse xml literal test" do
     file = File.join(@rdf_dir, "xml-literal-mixed.rdf")
     test_file(file, "http://www.example.com/books#book12345")
    end
  end

  # W3C Test suite from http://www.w3.org/2000/10/rdf-tests/rdfcore/
  describe "w3c rdfcore tests" do
    require 'rdf_helper'
    
    def self.positive_tests
      RdfHelper::TestCase.positive_parser_tests(RDFCORE_TEST, RDFCORE_DIR)
    end

    def self.negative_tests
      [] #RdfHelper::TestCase.negative_parser_tests(RDFCORE_TEST, RDFCORE_DIR) rescue []
    end
    
    it "should parse testcase" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF
		xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
		xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
		xmlns:test="http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#"
>
<!-- amp-in-url/Manifest.rdf -->
<test:PositiveParserTest rdf:about="http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001">

   <test:status>APPROVED</test:status>
   <test:approval rdf:resource="http://lists.w3.org/Archives/Public/w3c-rdfcore-wg/2001Sep/0326.html" />
   <!-- <test:discussion rdf:resource="pointer to archived email or other discussion" /> -->
   <!-- <test:description>
	-if we have a description, fill it in here -
   </test:description> -->

   <test:inputDocument>
      <test:RDF-XML-Document rdf:about="http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.rdf" />
   </test:inputDocument>

   <test:outputDocument>
      <test:NT-Document rdf:about="http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.nt" />
   </test:outputDocument>

</test:PositiveParserTest>
</rdf:RDF>
EOF

      triples = <<-EOF
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#PositiveParserTest> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#approval> <http://lists.w3.org/Archives/Public/w3c-rdfcore-wg/2001Sep/0326.html> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#inputDocument> <http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.rdf> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#outputDocument> <http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.nt> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#status> "APPROVED" .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.nt> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#NT-Document> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.rdf> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#RDF-XML-Document> .
EOF
      uri = "http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001"

      graph = parse(sampledoc, :base_uri => uri, :strict => true)
      graph.should be_equivalent_graph(triples, :about => uri, :trace => @debug)
    end
  
    # Negative parser tests should raise errors.
    describe "positive parser tests" do
      positive_tests.each do |t|
        #next unless t.about =~ /rdfms-rdf-names-use/
        #next unless t.name =~ /11/
        #puts t.inspect
        specify "#{t.name}: " + (t.description || "#{t.inputDocument} against #{t.outputDocument}") do
          t.run_test do |rdf_string|
            t.debug = []
            g = RDF::Graph.new
            RDF::RDFXML::Reader.new(rdf_string, :base_uri => t.about, :strict => true, :debug => t.debug).each do |statement|
              g << statement
            end
            g
          end
        end
      end
    end
    
    describe "negative parser tests" do
      negative_tests.each do |t|
        #next unless t.about =~ /rdfms-empty-property-elements/
        #next unless t.name =~ /1/
        #puts t.inspect
        specify "test #{t.name}: " + (t.description || t.inputDocument) do
          t.run_test do |rdf_string, parser|
            lambda do
              parser.parse(rdf_string, :base_uri => t.about, :strict => true, :debug => [])
              parser.graph.should be_empty
            end.should raise_error(RDF::ReaderError)
          end
        end
      end
    end
  end
  
  def parse(input, options)
    @debug = []
    graph = RDF::Graph.new
    RDF::RDFXML::Reader.new(input, options.merge(:debug => @debug)).each do |statement|
      graph << statement
    end
    graph
  end
end

