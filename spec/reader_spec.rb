# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/reader'

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe "RDF::RDFXML::Reader" do
  let(:logger) {RDF::Spec.logger}
  let!(:doap) {File.expand_path("../../etc/doap.rdf", __FILE__)}
  let!(:doap_nt) {File.expand_path("../../etc/doap.nt", __FILE__)}

  # @see lib/rdf/spec/reader.rb in rdf-spec
  it_behaves_like 'an RDF::Reader' do
    let(:reader_input) {File.read(doap)}
    let(:reader) {RDF::RDFXML::Reader.new(reader_input)}
    let(:reader_count) {File.open(doap_nt).each_line.to_a.length}
  end

  context "discovery" do
    {
      "rdfxml" => RDF::Reader.for(:rdfxml),
      "etc/foaf.rdf" => RDF::Reader.for("etc/foaf.rdf"),
      "foaf.rdf" => RDF::Reader.for(file_name: "foaf.rdf"),
      ".rdf" => RDF::Reader.for(file_extension: "rdf"),
      "application/rdf+xml" => RDF::Reader.for(content_type: "application/rdf+xml"),
    }.each_pair do |label, format|
      it "should discover '#{label}'" do
        expect(format).to eq RDF::RDFXML::Reader
      end
    end
  end

  context :interface do
    before(:each) do
      @sampledoc = %q(<?xml version="1.0" ?>
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
        </GenericXML>)
    end
    
    it "should yield reader" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::RDFXML::Reader)
      RDF::RDFXML::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      expect(RDF::RDFXML::Reader.new(@sampledoc)).to be_a(RDF::RDFXML::Reader)
    end
    
    it "should yield statements" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Statement).twice
      RDF::RDFXML::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::URI, RDF::URI, RDF::Literal).twice
      RDF::RDFXML::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end
  
  [:rexml, :nokogiri].each do |library|
    next if library == :nokogiri && !defined?(::Nokogiri)
    context library.to_s, library: library do
      before(:all) {@library = library}
      
      context "simple parsing" do
        it "should recognise and create single triple for empty non-RDF root" do
          sampledoc = %(<?xml version="1.0" ?>
            <NotRDF />)
            expected = %q(
              @prefix xml: <http://www.w3.org/XML/1998/namespace> .
              [ a xml:NotRDF] .
            )
          graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          expect(graph).to be_equivalent_graph(expected, about: "http://example.com/", logger: logger)
        end
  
        it "should parse on XML documents with multiple RDF nodes" do
          sampledoc = %q(<?xml version="1.0" ?>
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
            </GenericXML>)
          graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          objects = graph.statements.map {|s| s.object.value}.sort
          expect(objects).to include("Bar", "Foo")
        end
  
        it "should be able to parse a simple single-triple document" do
          sampledoc = %q(<?xml version="1.0" ?>
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
            </rdf:RDF>)

          expected = %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

            <http://example.org/joe> a <http://www.example.org/Thing>;
               <http://www.example.org/name> "bar"@en;
               <http://www.example.org/sampleText> "foo"^^xsd:string;
               <http://www.example.org/belongsTo> <http://tommorris.org/>;
               <http://www.example.org/hadADodgyRelationshipWith> [
                 <http://www.example.org/hadADodgyRelationshipWith> [
                   <http://www.example.org/hadADodgyRelationshipWith> [
                     <http://www.example.org/name> "Mary"@en];
                   <http://www.example.org/name> "Rob"@en];
                 <http://www.example.org/name> "Tom"@en] .
          )
          graph = parse(sampledoc, base_uri: "http://example.com/", validate: true)
          expect(graph).to be_equivalent_graph(expected, about: "http://example.com/", logger: logger)
        end

        it "should be able to handle Bags/Alts etc." do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:eg="http://example.org/">
              <rdf:Bag>
                <rdf:li rdf:resource="http://tommorris.org/" />
                <rdf:li rdf:resource="http://twitter.com/tommorris" />
              </rdf:Bag>
            </rdf:RDF>)
          graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          expect(graph.predicates.map(&:to_s)).to include("http://www.w3.org/1999/02/22-rdf-syntax-ns#_1", "http://www.w3.org/1999/02/22-rdf-syntax-ns#_2")
        end
      end

      it "extracts embedded RDF/XML" do
        svg = %(<?xml version="1.0" encoding="UTF-8"?>
          <svg width="12cm" height="4cm" viewBox="0 0 1200 400"
          xmlns:dc="http://purl.org/dc/terms/"
          xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
          xml:base="http://example.net/"
          xml:lang="fr"
          xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny">
            <desc property="dc:description">A yellow rectangle with sharp corners.</desc>
            <metadata>
              <rdf:RDF>
                <rdf:Description rdf:about="">
                  <dc:title>Test 0304</dc:title>
                </rdf:Description>
              </rdf:RDF>
            </metadata>
            <!-- Show outline of canvas using 'rect' element -->
            <rect x="1" y="1" width="1198" height="398"
                  fill="none" stroke="blue" stroke-width="2"/>
            <rect x="400" y="100" width="400" height="200"
                  fill="yellow" stroke="navy" stroke-width="10"  />
          </svg>
        )
        expected = %(
        	<http://example.net/> <http://purl.org/dc/terms/title> "Test 0304"@fr .
        )
        graph = parse(svg, base_uri: "http://example.com/", validate: true)
        expect(graph).to be_equivalent_graph(expected, logger: logger)
      end

      it "reads text from CDATA" do
        sampledoc = %(<?xml version="1.0" encoding="utf-8"?>
          <rdf:RDF
            xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
            xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
          >
            <rdf:Property rdf:about="http://www.w3.org/ns/oa#annotationService">
              <rdfs:comment><![CDATA[Text]]></rdfs:comment>
            </rdf:Property>
          </rdf:RDF>)
        expected = %(
        	<http://www.w3.org/ns/oa#annotationService> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Property> .
        	<http://www.w3.org/ns/oa#annotationService> <http://www.w3.org/2000/01/rdf-schema#comment> "Text" .
        )
        graph = parse(sampledoc, validate: true)
        expect(graph).to be_equivalent_graph(expected, logger: logger)
      end

      context :exceptions do
        it "should raise an error if rdf:aboutEach is used, as per the negative parser test rdfms-abouteach-error001 (rdf:aboutEach attribute)" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:eg="http://example.org/">

              <rdf:Bag rdf:ID="node">
                <rdf:li rdf:resource="http://example.org/node2"/>
              </rdf:Bag>

              <rdf:Description rdf:aboutEach="#node">
                <dc:rights xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:rights>

              </rdf:Description>

            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          end.to raise_error(RDF::ReaderError)
          expect(logger.to_s).to match(/Obsolete attribute .*aboutEach/)
        end

        it "should raise an error if rdf:aboutEachPrefix is used, as per the negative parser test rdfms-abouteach-error002 (rdf:aboutEachPrefix attribute)" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:eg="http://example.org/">

              <rdf:Description rdf:about="http://example.org/node">
                <eg:property>foo</eg:property>
              </rdf:Description>

              <rdf:Description rdf:aboutEachPrefix="http://example.org/">
                <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:creator>

              </rdf:Description>

            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          end.to raise_error(RDF::ReaderError)
          expect(logger.to_s).to match(/Obsolete attribute .*aboutEachPrefix/)
        end

        it "should fail if given a non-ID as an ID (as per rdfcore-rdfms-rdf-id-error001)" do
          sampledoc = %q(<?xml version="1.0"?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
              <rdf:Description rdf:ID='333-555-666' />
            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          end.to raise_error(RDF::ReaderError)
          expect(logger.to_s).to match(/ID addtribute '.*' must be a NCName/)
        end

        it "should make sure that the value of rdf:ID attributes match the XML Name production (child-element version)" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:eg="http://example.org/">
             <rdf:Description>
               <eg:prop rdf:ID="q:name" />
             </rdf:Description>
            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          end.to raise_error(RDF::ReaderError)
          expect(logger.to_s).to match(/ID addtribute '.*' must be a NCName/)
        end

        it "should make sure that the value of rdf:ID attributes match the XML Name production (data attribute version)" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:eg="http://example.org/">
              <rdf:Description rdf:ID="a/b" eg:prop="val" />
            </rdf:RDF>)
  
          expect do
            graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          end.to raise_error(RDF::ReaderError)
          expect(logger.to_s).to include("ID addtribute 'a/b' must be a NCName")
        end
  
        it "should detect bad bagIDs" do
          sampledoc = %q(<?xml version="1.0" ?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
              <rdf:Description rdf:bagID='333-555-666' />
            </rdf:RDF>)
    
          expect do
            graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          end.to raise_error(RDF::ReaderError)
          expect(logger.to_s).to match(/Obsolete attribute .*bagID/)
        end
      end
  
      context :reification do
        it "should be able to reify according to §2.17 of RDF/XML Syntax Specification" do
          sampledoc = %q(<?xml version="1.0"?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:ex="http://example.org/stuff/1.0/"
                     xml:base="http://example.org/triples/">
              <rdf:Description rdf:about="http://example.org/">
                <ex:prop rdf:ID="triple1">blah</ex:prop>
              </rdf:Description>
            </rdf:RDF>)

          expected = %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix ex: <http://example.org/stuff/1.0/> .
            <http://example.org/> ex:prop "blah" .
            <http://example.org/triples/#triple1> a rdf:Statement;
              rdf:subject <http://example.org/>;
              rdf:predicate ex:prop;
              rdf:object "blah" .
          )

          graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          expect(graph).to be_equivalent_graph(expected, about: "http://example.com/", logger: logger)
        end
      end
  
      context :entities do
        it "decodes attribute value" do
          sampledoc = %q(<?xml version="1.0"?>
            <!DOCTYPE rdf:RDF [<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#" >]>
            <rdf:RDF xmlns:rdf="&rdf;"
                     xmlns:ex="http://example.org/stuff/1.0/"
                     xml:base="http://example.org/triples/">
              <rdf:Description rdf:about="http://example.org/">
                <ex:prop rdf:ID="triple1">blah</ex:prop>
              </rdf:Description>
            </rdf:RDF>)

          expected = %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix ex: <http://example.org/stuff/1.0/> .
            <http://example.org/> ex:prop "blah" .
            <http://example.org/triples/#triple1> a rdf:Statement;
              rdf:subject <http://example.org/>;
              rdf:predicate ex:prop;
              rdf:object "blah" .
          )

          graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          expect(graph).to be_equivalent_graph(expected, about: "http://example.com/", logger: logger)
        end

        it "decodes element content" do
          sampledoc = %q(<?xml version="1.0"?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                     xmlns:ex="http://example.org/stuff/1.0/">
              <rdf:Description rdf:about="http://example.org/">
                <ex:prop>&gt;</ex:prop>
              </rdf:Description>
            </rdf:RDF>)

          expected = %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix ex: <http://example.org/stuff/1.0/> .
            <http://example.org/> ex:prop ">" .
          )

          graph = parse(sampledoc, base_uri: "http://example.com", validate: true)
          expect(graph).to be_equivalent_graph(expected, about: "http://example.com/", logger: logger)
        end
      end
    end
  end

  describe "Base IRI resolution" do
    # From https://gist.github.com/RubenVerborgh/39f0e8d63e33e435371a
    let(:xml) {%q{<outer xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="urn:ex:">
      <rdf:RDF xml:base="http://a/bb/ccc/d;p?q">
        <!-- RFC3986 normal examples -->
        <rdf:Description rdf:about="urn:ex:s001"><ex:p rdf:resource="g:h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s002"><ex:p rdf:resource="g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s003"><ex:p rdf:resource="./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s004"><ex:p rdf:resource="g/"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s005"><ex:p rdf:resource="/g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s006"><ex:p rdf:resource="//g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s007"><ex:p rdf:resource="?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s008"><ex:p rdf:resource="g?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s009"><ex:p rdf:resource="#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s010"><ex:p rdf:resource="g#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s011"><ex:p rdf:resource="g?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s012"><ex:p rdf:resource=";x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s013"><ex:p rdf:resource="g;x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s014"><ex:p rdf:resource="g;x?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s015"><ex:p rdf:resource=""/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s016"><ex:p rdf:resource="."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s017"><ex:p rdf:resource="./"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s018"><ex:p rdf:resource=".."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s019"><ex:p rdf:resource="../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s020"><ex:p rdf:resource="../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s021"><ex:p rdf:resource="../.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s022"><ex:p rdf:resource="../../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s023"><ex:p rdf:resource="../../g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/d;p?q">
        <!-- RFC3986 abnormal examples -->
        <rdf:Description rdf:about="urn:ex:s024"><ex:p rdf:resource="../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s025"><ex:p rdf:resource="../../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s026"><ex:p rdf:resource="/./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s027"><ex:p rdf:resource="/../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s028"><ex:p rdf:resource="g."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s029"><ex:p rdf:resource=".g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s030"><ex:p rdf:resource="g.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s031"><ex:p rdf:resource="..g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s032"><ex:p rdf:resource="./../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s033"><ex:p rdf:resource="./g/."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s034"><ex:p rdf:resource="g/./h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s035"><ex:p rdf:resource="g/../h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s036"><ex:p rdf:resource="g;x=1/./y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s037"><ex:p rdf:resource="g;x=1/../y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s038"><ex:p rdf:resource="g?y/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s039"><ex:p rdf:resource="g?y/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s040"><ex:p rdf:resource="g#s/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s041"><ex:p rdf:resource="g#s/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s042"><ex:p rdf:resource="http:g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/d/">
        <!-- RFC3986 normal examples with trailing slash in base IRI -->
        <rdf:Description rdf:about="urn:ex:s043"><ex:p rdf:resource="g:h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s044"><ex:p rdf:resource="g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s045"><ex:p rdf:resource="./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s046"><ex:p rdf:resource="g/"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s047"><ex:p rdf:resource="/g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s048"><ex:p rdf:resource="//g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s049"><ex:p rdf:resource="?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s050"><ex:p rdf:resource="g?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s051"><ex:p rdf:resource="#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s052"><ex:p rdf:resource="g#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s053"><ex:p rdf:resource="g?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s054"><ex:p rdf:resource=";x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s055"><ex:p rdf:resource="g;x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s056"><ex:p rdf:resource="g;x?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s057"><ex:p rdf:resource=""/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s058"><ex:p rdf:resource="."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s059"><ex:p rdf:resource="./"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s060"><ex:p rdf:resource=".."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s061"><ex:p rdf:resource="../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s062"><ex:p rdf:resource="../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s063"><ex:p rdf:resource="../.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s064"><ex:p rdf:resource="../../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s065"><ex:p rdf:resource="../../g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/d/">
        <!-- RFC3986 abnormal examples with trailing slash in base IRI -->
        <rdf:Description rdf:about="urn:ex:s066"><ex:p rdf:resource="../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s067"><ex:p rdf:resource="../../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s068"><ex:p rdf:resource="/./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s069"><ex:p rdf:resource="/../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s070"><ex:p rdf:resource="g."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s071"><ex:p rdf:resource=".g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s072"><ex:p rdf:resource="g.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s073"><ex:p rdf:resource="..g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s074"><ex:p rdf:resource="./../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s075"><ex:p rdf:resource="./g/."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s076"><ex:p rdf:resource="g/./h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s077"><ex:p rdf:resource="g/../h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s078"><ex:p rdf:resource="g;x=1/./y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s079"><ex:p rdf:resource="g;x=1/../y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s080"><ex:p rdf:resource="g?y/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s081"><ex:p rdf:resource="g?y/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s082"><ex:p rdf:resource="g#s/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s083"><ex:p rdf:resource="g#s/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s084"><ex:p rdf:resource="http:g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/./d;p?q">
        <!-- RFC3986 normal examples0 with ./ in the base IRI -->
        <rdf:Description rdf:about="urn:ex:s085"><ex:p rdf:resource="g:h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s086"><ex:p rdf:resource="g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s087"><ex:p rdf:resource="./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s088"><ex:p rdf:resource="g/"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s089"><ex:p rdf:resource="/g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s090"><ex:p rdf:resource="//g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s091"><ex:p rdf:resource="?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s092"><ex:p rdf:resource="g?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s093"><ex:p rdf:resource="#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s094"><ex:p rdf:resource="g#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s095"><ex:p rdf:resource="g?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s096"><ex:p rdf:resource=";x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s097"><ex:p rdf:resource="g;x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s098"><ex:p rdf:resource="g;x?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s099"><ex:p rdf:resource=""/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s100"><ex:p rdf:resource="."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s101"><ex:p rdf:resource="./"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s102"><ex:p rdf:resource=".."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s103"><ex:p rdf:resource="../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s104"><ex:p rdf:resource="../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s105"><ex:p rdf:resource="../.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s106"><ex:p rdf:resource="../../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s107"><ex:p rdf:resource="../../g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/./d;p?q">
        <!-- RFC3986 abnormal examples with ./ in the base IRI -->
        <rdf:Description rdf:about="urn:ex:s108"><ex:p rdf:resource="../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s109"><ex:p rdf:resource="../../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s110"><ex:p rdf:resource="/./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s111"><ex:p rdf:resource="/../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s112"><ex:p rdf:resource="g."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s113"><ex:p rdf:resource=".g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s114"><ex:p rdf:resource="g.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s115"><ex:p rdf:resource="..g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s116"><ex:p rdf:resource="./../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s117"><ex:p rdf:resource="./g/."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s118"><ex:p rdf:resource="g/./h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s119"><ex:p rdf:resource="g/../h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s120"><ex:p rdf:resource="g;x=1/./y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s121"><ex:p rdf:resource="g;x=1/../y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s122"><ex:p rdf:resource="g?y/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s123"><ex:p rdf:resource="g?y/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s124"><ex:p rdf:resource="g#s/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s125"><ex:p rdf:resource="g#s/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s126"><ex:p rdf:resource="http:g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/../d;p?q">
        <!-- RFC3986 normal examples with ../ in the base IRI -->
        <rdf:Description rdf:about="urn:ex:s127"><ex:p rdf:resource="g:h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s128"><ex:p rdf:resource="g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s129"><ex:p rdf:resource="./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s130"><ex:p rdf:resource="g/"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s131"><ex:p rdf:resource="/g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s132"><ex:p rdf:resource="//g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s133"><ex:p rdf:resource="?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s134"><ex:p rdf:resource="g?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s135"><ex:p rdf:resource="#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s136"><ex:p rdf:resource="g#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s137"><ex:p rdf:resource="g?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s138"><ex:p rdf:resource=";x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s139"><ex:p rdf:resource="g;x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s140"><ex:p rdf:resource="g;x?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s141"><ex:p rdf:resource=""/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s142"><ex:p rdf:resource="."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s143"><ex:p rdf:resource="./"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s144"><ex:p rdf:resource=".."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s145"><ex:p rdf:resource="../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s146"><ex:p rdf:resource="../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s147"><ex:p rdf:resource="../.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s148"><ex:p rdf:resource="../../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s149"><ex:p rdf:resource="../../g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/../d;p?q">
        <!-- RFC3986 abnormal examples with ../ in the base IRI -->
        <rdf:Description rdf:about="urn:ex:s150"><ex:p rdf:resource="../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s151"><ex:p rdf:resource="../../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s152"><ex:p rdf:resource="/./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s153"><ex:p rdf:resource="/../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s154"><ex:p rdf:resource="g."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s155"><ex:p rdf:resource=".g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s156"><ex:p rdf:resource="g.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s157"><ex:p rdf:resource="..g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s158"><ex:p rdf:resource="./../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s159"><ex:p rdf:resource="./g/."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s160"><ex:p rdf:resource="g/./h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s161"><ex:p rdf:resource="g/../h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s162"><ex:p rdf:resource="g;x=1/./y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s163"><ex:p rdf:resource="g;x=1/../y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s164"><ex:p rdf:resource="g?y/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s165"><ex:p rdf:resource="g?y/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s166"><ex:p rdf:resource="g#s/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s167"><ex:p rdf:resource="g#s/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s168"><ex:p rdf:resource="http:g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/.">
        <!-- RFC3986 normal examples with trailing ./ in the base IRI -->
        <rdf:Description rdf:about="urn:ex:s169"><ex:p rdf:resource="g:h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s170"><ex:p rdf:resource="g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s171"><ex:p rdf:resource="./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s172"><ex:p rdf:resource="g/"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s173"><ex:p rdf:resource="/g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s174"><ex:p rdf:resource="//g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s175"><ex:p rdf:resource="?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s176"><ex:p rdf:resource="g?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s177"><ex:p rdf:resource="#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s178"><ex:p rdf:resource="g#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s179"><ex:p rdf:resource="g?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s180"><ex:p rdf:resource=";x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s181"><ex:p rdf:resource="g;x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s182"><ex:p rdf:resource="g;x?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s183"><ex:p rdf:resource=""/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s184"><ex:p rdf:resource="."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s185"><ex:p rdf:resource="./"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s186"><ex:p rdf:resource=".."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s187"><ex:p rdf:resource="../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s188"><ex:p rdf:resource="../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s189"><ex:p rdf:resource="../.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s190"><ex:p rdf:resource="../../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s191"><ex:p rdf:resource="../../g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/.">
        <!-- RFC3986 abnormal examples with trailing ./ in the base IRI -->
        <rdf:Description rdf:about="urn:ex:s192"><ex:p rdf:resource="../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s193"><ex:p rdf:resource="../../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s194"><ex:p rdf:resource="/./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s195"><ex:p rdf:resource="/../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s196"><ex:p rdf:resource="g."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s197"><ex:p rdf:resource=".g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s198"><ex:p rdf:resource="g.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s199"><ex:p rdf:resource="..g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s200"><ex:p rdf:resource="./../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s201"><ex:p rdf:resource="./g/."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s202"><ex:p rdf:resource="g/./h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s203"><ex:p rdf:resource="g/../h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s204"><ex:p rdf:resource="g;x=1/./y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s205"><ex:p rdf:resource="g;x=1/../y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s206"><ex:p rdf:resource="g?y/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s207"><ex:p rdf:resource="g?y/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s208"><ex:p rdf:resource="g#s/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s209"><ex:p rdf:resource="g#s/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s210"><ex:p rdf:resource="http:g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/..">
        <!-- RFC3986 normal examples with trailing ../ in the base IRI -->
        <rdf:Description rdf:about="urn:ex:s211"><ex:p rdf:resource="g:h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s212"><ex:p rdf:resource="g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s213"><ex:p rdf:resource="./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s214"><ex:p rdf:resource="g/"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s215"><ex:p rdf:resource="/g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s216"><ex:p rdf:resource="//g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s217"><ex:p rdf:resource="?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s218"><ex:p rdf:resource="g?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s219"><ex:p rdf:resource="#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s220"><ex:p rdf:resource="g#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s221"><ex:p rdf:resource="g?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s222"><ex:p rdf:resource=";x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s223"><ex:p rdf:resource="g;x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s224"><ex:p rdf:resource="g;x?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s225"><ex:p rdf:resource=""/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s226"><ex:p rdf:resource="."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s227"><ex:p rdf:resource="./"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s228"><ex:p rdf:resource=".."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s229"><ex:p rdf:resource="../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s230"><ex:p rdf:resource="../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s231"><ex:p rdf:resource="../.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s232"><ex:p rdf:resource="../../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s233"><ex:p rdf:resource="../../g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="http://a/bb/ccc/..">
        <!-- RFC3986 abnormal examples with trailing ../ in the base IRI -->
        <rdf:Description rdf:about="urn:ex:s234"><ex:p rdf:resource="../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s235"><ex:p rdf:resource="../../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s236"><ex:p rdf:resource="/./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s237"><ex:p rdf:resource="/../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s238"><ex:p rdf:resource="g."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s239"><ex:p rdf:resource=".g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s240"><ex:p rdf:resource="g.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s241"><ex:p rdf:resource="..g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s242"><ex:p rdf:resource="./../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s243"><ex:p rdf:resource="./g/."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s244"><ex:p rdf:resource="g/./h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s245"><ex:p rdf:resource="g/../h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s246"><ex:p rdf:resource="g;x=1/./y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s247"><ex:p rdf:resource="g;x=1/../y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s248"><ex:p rdf:resource="g?y/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s249"><ex:p rdf:resource="g?y/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s250"><ex:p rdf:resource="g#s/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s251"><ex:p rdf:resource="g#s/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s252"><ex:p rdf:resource="http:g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="file:///a/bb/ccc/d;p?q">
        <!-- RFC3986 normal examples with file path -->
        <rdf:Description rdf:about="urn:ex:s253"><ex:p rdf:resource="g:h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s254"><ex:p rdf:resource="g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s255"><ex:p rdf:resource="./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s256"><ex:p rdf:resource="g/"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s257"><ex:p rdf:resource="/g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s258"><ex:p rdf:resource="//g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s259"><ex:p rdf:resource="?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s260"><ex:p rdf:resource="g?y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s261"><ex:p rdf:resource="#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s262"><ex:p rdf:resource="g#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s263"><ex:p rdf:resource="g?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s264"><ex:p rdf:resource=";x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s265"><ex:p rdf:resource="g;x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s266"><ex:p rdf:resource="g;x?y#s"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s267"><ex:p rdf:resource=""/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s268"><ex:p rdf:resource="."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s269"><ex:p rdf:resource="./"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s270"><ex:p rdf:resource=".."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s271"><ex:p rdf:resource="../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s272"><ex:p rdf:resource="../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s273"><ex:p rdf:resource="../.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s274"><ex:p rdf:resource="../../"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s275"><ex:p rdf:resource="../../g"/></rdf:Description>
      </rdf:RDF>

      <rdf:RDF xml:base="file:///a/bb/ccc/d;p?q">
        <!-- RFC3986 abnormal examples with file path -->
        <rdf:Description rdf:about="urn:ex:s276"><ex:p rdf:resource="../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s277"><ex:p rdf:resource="../../../../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s278"><ex:p rdf:resource="/./g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s279"><ex:p rdf:resource="/../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s280"><ex:p rdf:resource="g."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s281"><ex:p rdf:resource=".g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s282"><ex:p rdf:resource="g.."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s283"><ex:p rdf:resource="..g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s284"><ex:p rdf:resource="./../g"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s285"><ex:p rdf:resource="./g/."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s286"><ex:p rdf:resource="g/./h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s287"><ex:p rdf:resource="g/../h"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s288"><ex:p rdf:resource="g;x=1/./y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s289"><ex:p rdf:resource="g;x=1/../y"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s290"><ex:p rdf:resource="g?y/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s291"><ex:p rdf:resource="g?y/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s292"><ex:p rdf:resource="g#s/./x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s293"><ex:p rdf:resource="g#s/../x"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s294"><ex:p rdf:resource="http:g"/></rdf:Description>
      </rdf:RDF>

      <!-- additional cases -->
      <rdf:RDF xml:base="http://abc/def/ghi">
        <rdf:Description rdf:about="urn:ex:s295"><ex:p rdf:resource="."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s296"><ex:p rdf:resource=".?a=b"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s297"><ex:p rdf:resource=".#a=b"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s298"><ex:p rdf:resource=".."/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s299"><ex:p rdf:resource="..?a=b"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s300"><ex:p rdf:resource="..#a=b"/></rdf:Description>
      </rdf:RDF>
      <rdf:RDF xml:base="http://ab//de//ghi">
        <rdf:Description rdf:about="urn:ex:s301"><ex:p rdf:resource="xyz"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s302"><ex:p rdf:resource="./xyz"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s303"><ex:p rdf:resource="../xyz"/></rdf:Description>
      </rdf:RDF>
      <rdf:RDF xml:base="http://abc/d:f/ghi">
        <rdf:Description rdf:about="urn:ex:s304"><ex:p rdf:resource="xyz"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s305"><ex:p rdf:resource="./xyz"/></rdf:Description>
        <rdf:Description rdf:about="urn:ex:s306"><ex:p rdf:resource="../xyz"/></rdf:Description>
      </rdf:RDF>
    </outer>}}
    let(:nt) {%q{
      # RFC3986 normal examples

      <urn:ex:s001> <urn:ex:p> <g:h>.
      <urn:ex:s002> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s003> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s004> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s005> <urn:ex:p> <http://a/g>.
      <urn:ex:s006> <urn:ex:p> <http://g>.
      <urn:ex:s007> <urn:ex:p> <http://a/bb/ccc/d;p?y>.
      <urn:ex:s008> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s009> <urn:ex:p> <http://a/bb/ccc/d;p?q#s>.
      <urn:ex:s010> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s011> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s012> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s013> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s014> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s015> <urn:ex:p> <http://a/bb/ccc/d;p?q>.
      <urn:ex:s016> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s017> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s018> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s019> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s020> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s021> <urn:ex:p> <http://a/>.
      <urn:ex:s022> <urn:ex:p> <http://a/>.
      <urn:ex:s023> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples

      <urn:ex:s024> <urn:ex:p> <http://a/g>.
      <urn:ex:s025> <urn:ex:p> <http://a/g>.
      <urn:ex:s026> <urn:ex:p> <http://a/g>.
      <urn:ex:s027> <urn:ex:p> <http://a/g>.
      <urn:ex:s028> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s029> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s030> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s031> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s032> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s033> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s034> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s035> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s036> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s037> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s038> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s039> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s040> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s041> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s042> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing slash in base IRI

      <urn:ex:s043> <urn:ex:p> <g:h>.
      <urn:ex:s044> <urn:ex:p> <http://a/bb/ccc/d/g>.
      <urn:ex:s045> <urn:ex:p> <http://a/bb/ccc/d/g>.
      <urn:ex:s046> <urn:ex:p> <http://a/bb/ccc/d/g/>.
      <urn:ex:s047> <urn:ex:p> <http://a/g>.
      <urn:ex:s048> <urn:ex:p> <http://g>.
      <urn:ex:s049> <urn:ex:p> <http://a/bb/ccc/d/?y>.
      <urn:ex:s050> <urn:ex:p> <http://a/bb/ccc/d/g?y>.
      <urn:ex:s051> <urn:ex:p> <http://a/bb/ccc/d/#s>.
      <urn:ex:s052> <urn:ex:p> <http://a/bb/ccc/d/g#s>.
      <urn:ex:s053> <urn:ex:p> <http://a/bb/ccc/d/g?y#s>.
      <urn:ex:s054> <urn:ex:p> <http://a/bb/ccc/d/;x>.
      <urn:ex:s055> <urn:ex:p> <http://a/bb/ccc/d/g;x>.
      <urn:ex:s056> <urn:ex:p> <http://a/bb/ccc/d/g;x?y#s>.
      <urn:ex:s057> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s058> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s059> <urn:ex:p> <http://a/bb/ccc/d/>.
      <urn:ex:s060> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s061> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s062> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s063> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s064> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s065> <urn:ex:p> <http://a/bb/g>.

      # RFC3986 abnormal examples with trailing slash in base IRI

      <urn:ex:s066> <urn:ex:p> <http://a/g>.
      <urn:ex:s067> <urn:ex:p> <http://a/g>.
      <urn:ex:s068> <urn:ex:p> <http://a/g>.
      <urn:ex:s069> <urn:ex:p> <http://a/g>.
      <urn:ex:s070> <urn:ex:p> <http://a/bb/ccc/d/g.>.
      <urn:ex:s071> <urn:ex:p> <http://a/bb/ccc/d/.g>.
      <urn:ex:s072> <urn:ex:p> <http://a/bb/ccc/d/g..>.
      <urn:ex:s073> <urn:ex:p> <http://a/bb/ccc/d/..g>.
      <urn:ex:s074> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s075> <urn:ex:p> <http://a/bb/ccc/d/g/>.
      <urn:ex:s076> <urn:ex:p> <http://a/bb/ccc/d/g/h>.
      <urn:ex:s077> <urn:ex:p> <http://a/bb/ccc/d/h>.
      <urn:ex:s078> <urn:ex:p> <http://a/bb/ccc/d/g;x=1/y>.
      <urn:ex:s079> <urn:ex:p> <http://a/bb/ccc/d/y>.
      <urn:ex:s080> <urn:ex:p> <http://a/bb/ccc/d/g?y/./x>.
      <urn:ex:s081> <urn:ex:p> <http://a/bb/ccc/d/g?y/../x>.
      <urn:ex:s082> <urn:ex:p> <http://a/bb/ccc/d/g#s/./x>.
      <urn:ex:s083> <urn:ex:p> <http://a/bb/ccc/d/g#s/../x>.
      <urn:ex:s084> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with /. in the base IRI

      <urn:ex:s085> <urn:ex:p> <g:h>.
      <urn:ex:s086> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s087> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s088> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s089> <urn:ex:p> <http://a/g>.
      <urn:ex:s090> <urn:ex:p> <http://g>.
      <urn:ex:s091> <urn:ex:p> <http://a/bb/ccc/./d;p?y>.
      <urn:ex:s092> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s093> <urn:ex:p> <http://a/bb/ccc/./d;p?q#s>.
      <urn:ex:s094> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s095> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s096> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s097> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s098> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s099> <urn:ex:p> <http://a/bb/ccc/./d;p?q>.
      <urn:ex:s100> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s101> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s102> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s103> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s104> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s105> <urn:ex:p> <http://a/>.
      <urn:ex:s106> <urn:ex:p> <http://a/>.
      <urn:ex:s107> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with /. in the base IRI

      <urn:ex:s108> <urn:ex:p> <http://a/g>.
      <urn:ex:s109> <urn:ex:p> <http://a/g>.
      <urn:ex:s110> <urn:ex:p> <http://a/g>.
      <urn:ex:s111> <urn:ex:p> <http://a/g>.
      <urn:ex:s112> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s113> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s114> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s115> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s116> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s117> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s118> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s119> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s120> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s121> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s122> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s123> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s124> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s125> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s126> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with /.. in the base IRI

      <urn:ex:s127> <urn:ex:p> <g:h>.
      <urn:ex:s128> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s129> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s130> <urn:ex:p> <http://a/bb/g/>.
      <urn:ex:s131> <urn:ex:p> <http://a/g>.
      <urn:ex:s132> <urn:ex:p> <http://g>.
      <urn:ex:s133> <urn:ex:p> <http://a/bb/ccc/../d;p?y>.
      <urn:ex:s134> <urn:ex:p> <http://a/bb/g?y>.
      <urn:ex:s135> <urn:ex:p> <http://a/bb/ccc/../d;p?q#s>.
      <urn:ex:s136> <urn:ex:p> <http://a/bb/g#s>.
      <urn:ex:s137> <urn:ex:p> <http://a/bb/g?y#s>.
      <urn:ex:s138> <urn:ex:p> <http://a/bb/;x>.
      <urn:ex:s139> <urn:ex:p> <http://a/bb/g;x>.
      <urn:ex:s140> <urn:ex:p> <http://a/bb/g;x?y#s>.
      <urn:ex:s141> <urn:ex:p> <http://a/bb/ccc/../d;p?q>.
      <urn:ex:s142> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s143> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s144> <urn:ex:p> <http://a/>.
      <urn:ex:s145> <urn:ex:p> <http://a/>.
      <urn:ex:s146> <urn:ex:p> <http://a/g>.
      <urn:ex:s147> <urn:ex:p> <http://a/>.
      <urn:ex:s148> <urn:ex:p> <http://a/>.
      <urn:ex:s149> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with /.. in the base IRI

      <urn:ex:s150> <urn:ex:p> <http://a/g>.
      <urn:ex:s151> <urn:ex:p> <http://a/g>.
      <urn:ex:s152> <urn:ex:p> <http://a/g>.
      <urn:ex:s153> <urn:ex:p> <http://a/g>.
      <urn:ex:s154> <urn:ex:p> <http://a/bb/g.>.
      <urn:ex:s155> <urn:ex:p> <http://a/bb/.g>.
      <urn:ex:s156> <urn:ex:p> <http://a/bb/g..>.
      <urn:ex:s157> <urn:ex:p> <http://a/bb/..g>.
      <urn:ex:s158> <urn:ex:p> <http://a/g>.
      <urn:ex:s159> <urn:ex:p> <http://a/bb/g/>.
      <urn:ex:s160> <urn:ex:p> <http://a/bb/g/h>.
      <urn:ex:s161> <urn:ex:p> <http://a/bb/h>.
      <urn:ex:s162> <urn:ex:p> <http://a/bb/g;x=1/y>.
      <urn:ex:s163> <urn:ex:p> <http://a/bb/y>.
      <urn:ex:s164> <urn:ex:p> <http://a/bb/g?y/./x>.
      <urn:ex:s165> <urn:ex:p> <http://a/bb/g?y/../x>.
      <urn:ex:s166> <urn:ex:p> <http://a/bb/g#s/./x>.
      <urn:ex:s167> <urn:ex:p> <http://a/bb/g#s/../x>.
      <urn:ex:s168> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing /. in the base IRI

      <urn:ex:s169> <urn:ex:p> <g:h>.
      <urn:ex:s170> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s171> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s172> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s173> <urn:ex:p> <http://a/g>.
      <urn:ex:s174> <urn:ex:p> <http://g>.
      <urn:ex:s175> <urn:ex:p> <http://a/bb/ccc/.?y>.
      <urn:ex:s176> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s177> <urn:ex:p> <http://a/bb/ccc/.#s>.
      <urn:ex:s178> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s179> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s180> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s181> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s182> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s183> <urn:ex:p> <http://a/bb/ccc/.>.
      <urn:ex:s184> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s185> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s186> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s187> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s188> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s189> <urn:ex:p> <http://a/>.
      <urn:ex:s190> <urn:ex:p> <http://a/>.
      <urn:ex:s191> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing /. in the base IRI

      <urn:ex:s192> <urn:ex:p> <http://a/g>.
      <urn:ex:s193> <urn:ex:p> <http://a/g>.
      <urn:ex:s194> <urn:ex:p> <http://a/g>.
      <urn:ex:s195> <urn:ex:p> <http://a/g>.
      <urn:ex:s196> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s197> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s198> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s199> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s200> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s201> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s202> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s203> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s204> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s205> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s206> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s207> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s208> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s209> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s210> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with trailing /.. in the base IRI

      <urn:ex:s211> <urn:ex:p> <g:h>.
      <urn:ex:s212> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s213> <urn:ex:p> <http://a/bb/ccc/g>.
      <urn:ex:s214> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s215> <urn:ex:p> <http://a/g>.
      <urn:ex:s216> <urn:ex:p> <http://g>.
      <urn:ex:s217> <urn:ex:p> <http://a/bb/ccc/..?y>.
      <urn:ex:s218> <urn:ex:p> <http://a/bb/ccc/g?y>.
      <urn:ex:s219> <urn:ex:p> <http://a/bb/ccc/..#s>.
      <urn:ex:s220> <urn:ex:p> <http://a/bb/ccc/g#s>.
      <urn:ex:s221> <urn:ex:p> <http://a/bb/ccc/g?y#s>.
      <urn:ex:s222> <urn:ex:p> <http://a/bb/ccc/;x>.
      <urn:ex:s223> <urn:ex:p> <http://a/bb/ccc/g;x>.
      <urn:ex:s224> <urn:ex:p> <http://a/bb/ccc/g;x?y#s>.
      <urn:ex:s225> <urn:ex:p> <http://a/bb/ccc/..>.
      <urn:ex:s226> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s227> <urn:ex:p> <http://a/bb/ccc/>.
      <urn:ex:s228> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s229> <urn:ex:p> <http://a/bb/>.
      <urn:ex:s230> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s231> <urn:ex:p> <http://a/>.
      <urn:ex:s232> <urn:ex:p> <http://a/>.
      <urn:ex:s233> <urn:ex:p> <http://a/g>.

      # RFC3986 abnormal examples with trailing /.. in the base IRI

      <urn:ex:s234> <urn:ex:p> <http://a/g>.
      <urn:ex:s235> <urn:ex:p> <http://a/g>.
      <urn:ex:s236> <urn:ex:p> <http://a/g>.
      <urn:ex:s237> <urn:ex:p> <http://a/g>.
      <urn:ex:s238> <urn:ex:p> <http://a/bb/ccc/g.>.
      <urn:ex:s239> <urn:ex:p> <http://a/bb/ccc/.g>.
      <urn:ex:s240> <urn:ex:p> <http://a/bb/ccc/g..>.
      <urn:ex:s241> <urn:ex:p> <http://a/bb/ccc/..g>.
      <urn:ex:s242> <urn:ex:p> <http://a/bb/g>.
      <urn:ex:s243> <urn:ex:p> <http://a/bb/ccc/g/>.
      <urn:ex:s244> <urn:ex:p> <http://a/bb/ccc/g/h>.
      <urn:ex:s245> <urn:ex:p> <http://a/bb/ccc/h>.
      <urn:ex:s246> <urn:ex:p> <http://a/bb/ccc/g;x=1/y>.
      <urn:ex:s247> <urn:ex:p> <http://a/bb/ccc/y>.
      <urn:ex:s248> <urn:ex:p> <http://a/bb/ccc/g?y/./x>.
      <urn:ex:s249> <urn:ex:p> <http://a/bb/ccc/g?y/../x>.
      <urn:ex:s250> <urn:ex:p> <http://a/bb/ccc/g#s/./x>.
      <urn:ex:s251> <urn:ex:p> <http://a/bb/ccc/g#s/../x>.
      <urn:ex:s252> <urn:ex:p> <http:g>.

      # RFC3986 normal examples with file path

      <urn:ex:s253> <urn:ex:p> <g:h>.
      <urn:ex:s254> <urn:ex:p> <file:///a/bb/ccc/g>.
      <urn:ex:s255> <urn:ex:p> <file:///a/bb/ccc/g>.
      <urn:ex:s256> <urn:ex:p> <file:///a/bb/ccc/g/>.
      <urn:ex:s257> <urn:ex:p> <file:///g>.
      <urn:ex:s258> <urn:ex:p> <file://g>.
      <urn:ex:s259> <urn:ex:p> <file:///a/bb/ccc/d;p?y>.
      <urn:ex:s260> <urn:ex:p> <file:///a/bb/ccc/g?y>.
      <urn:ex:s261> <urn:ex:p> <file:///a/bb/ccc/d;p?q#s>.
      <urn:ex:s262> <urn:ex:p> <file:///a/bb/ccc/g#s>.
      <urn:ex:s263> <urn:ex:p> <file:///a/bb/ccc/g?y#s>.
      <urn:ex:s264> <urn:ex:p> <file:///a/bb/ccc/;x>.
      <urn:ex:s265> <urn:ex:p> <file:///a/bb/ccc/g;x>.
      <urn:ex:s266> <urn:ex:p> <file:///a/bb/ccc/g;x?y#s>.
      <urn:ex:s267> <urn:ex:p> <file:///a/bb/ccc/d;p?q>.
      <urn:ex:s268> <urn:ex:p> <file:///a/bb/ccc/>.
      <urn:ex:s269> <urn:ex:p> <file:///a/bb/ccc/>.
      <urn:ex:s270> <urn:ex:p> <file:///a/bb/>.
      <urn:ex:s271> <urn:ex:p> <file:///a/bb/>.
      <urn:ex:s272> <urn:ex:p> <file:///a/bb/g>.
      <urn:ex:s273> <urn:ex:p> <file:///a/>.
      <urn:ex:s274> <urn:ex:p> <file:///a/>.
      <urn:ex:s275> <urn:ex:p> <file:///a/g>.

      # RFC3986 abnormal examples with file path

      <urn:ex:s276> <urn:ex:p> <file:///g>.
      <urn:ex:s277> <urn:ex:p> <file:///g>.
      <urn:ex:s278> <urn:ex:p> <file:///g>.
      <urn:ex:s279> <urn:ex:p> <file:///g>.
      <urn:ex:s280> <urn:ex:p> <file:///a/bb/ccc/g.>.
      <urn:ex:s281> <urn:ex:p> <file:///a/bb/ccc/.g>.
      <urn:ex:s282> <urn:ex:p> <file:///a/bb/ccc/g..>.
      <urn:ex:s283> <urn:ex:p> <file:///a/bb/ccc/..g>.
      <urn:ex:s284> <urn:ex:p> <file:///a/bb/g>.
      <urn:ex:s285> <urn:ex:p> <file:///a/bb/ccc/g/>.
      <urn:ex:s286> <urn:ex:p> <file:///a/bb/ccc/g/h>.
      <urn:ex:s287> <urn:ex:p> <file:///a/bb/ccc/h>.
      <urn:ex:s288> <urn:ex:p> <file:///a/bb/ccc/g;x=1/y>.
      <urn:ex:s289> <urn:ex:p> <file:///a/bb/ccc/y>.
      <urn:ex:s290> <urn:ex:p> <file:///a/bb/ccc/g?y/./x>.
      <urn:ex:s291> <urn:ex:p> <file:///a/bb/ccc/g?y/../x>.
      <urn:ex:s292> <urn:ex:p> <file:///a/bb/ccc/g#s/./x>.
      <urn:ex:s293> <urn:ex:p> <file:///a/bb/ccc/g#s/../x>.
      <urn:ex:s294> <urn:ex:p> <http:g>.

      # additional cases

      <urn:ex:s295> <urn:ex:p> <http://abc/def/>.
      <urn:ex:s296> <urn:ex:p> <http://abc/def/?a=b>.
      <urn:ex:s297> <urn:ex:p> <http://abc/def/#a=b>.
      <urn:ex:s298> <urn:ex:p> <http://abc/>.
      <urn:ex:s299> <urn:ex:p> <http://abc/?a=b>.
      <urn:ex:s300> <urn:ex:p> <http://abc/#a=b>.

      <urn:ex:s301> <urn:ex:p> <http://ab//de//xyz>.
      <urn:ex:s302> <urn:ex:p> <http://ab//de//xyz>.
      <urn:ex:s303> <urn:ex:p> <http://ab//de/xyz>.

      <urn:ex:s304> <urn:ex:p> <http://abc/d:f/xyz>.
      <urn:ex:s305> <urn:ex:p> <http://abc/d:f/xyz>.
      <urn:ex:s306> <urn:ex:p> <http://abc/xyz>.
    }}
    it "produces equivalent triples" do
      nt_str = RDF::NTriples::Reader.new(nt).dump(:ntriples)
      xml_str = RDF::RDFXML::Reader.new(xml).dump(:ntriples)
      expect(xml_str).to eql(nt_str)
    end
  end

  def parse(input, options)
    RDF::Repository.new << RDF::RDFXML::Reader.new(input, options.merge(logger: logger, library: @library))
  end
end

