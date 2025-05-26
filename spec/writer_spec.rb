require_relative 'spec_helper'
require 'rdf/spec/writer'
require 'rdf/vocab'
autoload :CGI, 'cgi'

class FOO < RDF::Vocabulary("http://foo/"); end

describe "RDF::RDFXML::Writer" do
  let(:logger) {RDF::Spec.logger}
  after(:each) {|example| puts logger.to_s if example.exception}

  it_behaves_like 'an RDF::Writer' do
    let(:writer) {RDF::RDFXML::Writer.new(::StringIO.new)}
  end

  describe "#buffer" do
    context "typed resources" do
      context "resource without type" do
        subject do
          nt = %(<http://release/> <http://purl.org/dc/terms/title> "foo" .)
          serialize(nt, attributes: :untyped)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
  
      context "resource with type" do
        subject do
          nt = %(
            <http://release/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://foo/Release> .
            <http://release/> <http://purl.org/dc/terms/title> "foo" .
          )
          serialize(nt, attributes: :untyped)
        end

        {
          "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
          "/rdf:RDF/foo:Release/@dc:title" =>"foo",
          "/rdf:RDF/foo:Release/rdf:type" => false
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
    end

    context "with illegal content" do
      context "in attribute", skip: !defined?(::Nokogiri) do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo & bar" .
          )
          serialize(nt, attributes: :untyped)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo & bar",
          "/rdf:RDF/rdf:Description/dc:title" => false
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
      context "in element" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo & bar" .
          )
          serialize(nt, attributes: :none)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => false,
          "/rdf:RDF/rdf:Description/dc:title/text()" => "foo &amp; bar"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
    end

    context "with children" do
      let(:nt) {%(
        <http://release/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://foo/Release> .
        <http://release/> <http://purl.org/dc/terms/title> "foo" .
        <http://release/contributor> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://foo/Contributor> .
        <http://release/contributor> <http://purl.org/dc/terms/title> "bar" .
        <http://release/> <http://foo/releaseContributor> <http://release/contributor> .
      )}
      subject {serialize(nt, attributes: :untyped)}

      it "reproduces graph" do
        expect(parse(subject)).to be_equivalent_graph(nt, logger: logger)
      end

      {
        "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
        "/rdf:RDF/foo:Release/@dc:title" => "foo",
        "/rdf:RDF/foo:Release/foo:releaseContributor/foo:Contributor/@rdf:about" => "http://release/contributor"
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          expect(subject).to have_xpath(path, value, {}, logger)
        end
      end

      context "max_depth: 0" do
        subject {serialize(nt, attributes: :untyped, max_depth: 0)}

        it "reproduces graph" do
          expect(parse(subject)).to be_equivalent_graph(nt, logger: logger)
        end

        {
          "/rdf:RDF/foo:Release/@rdf:about" => "http://release/",
          "/rdf:RDF/foo:Release/@dc:title" => "foo",
          "/rdf:RDF/foo:Release/foo:releaseContributor/@rdf:resource" => "http://release/contributor",
          "/rdf:RDF/foo:Contributor/@dc:title" => "bar",
          "/rdf:RDF/foo:Contributor/@rdf:about" => "http://release/contributor",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
    end
  
    context "with sequences" do
      context "rdf:Seq with rdf:_n" do
        subject do
          nt = %(
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq> .
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_1> <http://example/first> .
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_2> <http://example/second> .
          )
          serialize(nt)
        end

        {
          "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Seq/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Seq/rdf:_2[@rdf:resource="http://example/second"]) => /second/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
  
      context "rdf:Seq with rdf:_n in proper sequence" do
        subject do
          nt = %(
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq> .
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_2> <http://example/second> .
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_1> <http://example/first> .
          )
          serialize(nt)
        end

        {
          "/rdf:RDF/rdf:Seq/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Seq/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Seq/rdf:_2[@rdf:resource="http://example/second"]) => /secon/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end

      context "rdf:Bag with rdf:_n" do
        subject do
          nt = %(
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Bag> .
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_1> <http://example/first> .
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_2> <http://example/second> .
          )
          serialize(nt)
        end

        {
          "/rdf:RDF/rdf:Bag/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Bag/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Bag/rdf:_2[@rdf:resource="http://example/second"]) => /secon/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end

      context "rdf:Alt with rdf:_n" do
        subject do
          nt = %(
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Alt> .
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_1> <http://example/first> .
            <http://example/seq> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_2> <http://example/second> .
          )
          serialize(nt)
        end

        {
          "/rdf:RDF/rdf:Alt/@rdf:about" => "http://example/seq",
          %(/rdf:RDF/rdf:Alt/rdf:_1[@rdf:resource="http://example/first"]) => /first/,
          %(/rdf:RDF/rdf:Alt/rdf:_2[@rdf:resource="http://example/second"]) => /secon/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
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
              statements = parse(ttl, base_uri: "http://foo/", format: :ttl)
              serialize(statements)
            end
            match.each do |path, value|
              it "returns #{value.inspect} for xpath #{path}" do
                expect(subject).to have_xpath(path, value, {}, logger)
              end
            end
          end
        end
      end
    end

    context "with untyped literals" do
      context ":attributes == :none" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo" .
          )
          serialize(nt, attributes: :none)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title/text()" => "foo"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
  
      [:untyped, :typed].each do |opt|
        context ":attributes == #{opt}" do
          subject do
            nt = %(
              <http://release/> <http://purl.org/dc/terms/title> "foo" .
            )
            serialize(nt, attributes: opt)
          end

          {
            "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
            "/rdf:RDF/rdf:Description/@dc:title" => "foo"
          }.each do |path, value|
            it "returns #{value.inspect} for xpath #{path}" do
              expect(subject).to have_xpath(path, value, {}, logger)
            end
          end
        end
      end
  
      context "untyped without lang if attribute lang set" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo"@de .
          )
          serialize(nt, attributes: :untyped, lang: "de")
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end

      context "with language" do
        context "property for title" do
          subject do
            nt = %(
              <http://release/> <http://purl.org/dc/terms/title> "foo"@en-us .
            )
            serialize(nt, attributes: :untyped, lang: "de")
          end

          {
            "/rdf:RDF/@xml:lang" => "de",
            "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
            "/rdf:RDF/rdf:Description/dc:title" => true,
            "/rdf:RDF/rdf:Description/dc:title/@xml:lang" => "en-us",
            "/rdf:RDF/rdf:Description/dc:title/text()" => "foo",
          }.each do |path, value|
            it "returns #{value.inspect} for xpath #{path}" do
              expect(subject).to have_xpath(path, value, {}, logger)
            end
          end
        end
      end
  
      context "attribute if lang is default" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo"@de .
          )
          serialize(nt, attributes: :untyped, lang: "de")
        end

        {
          "/rdf:RDF/@xml:lang" => "de",
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
  
      context "untyped as property if lang set and no default" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo"@de .
          )
          serialize(nt, attributes: :untyped)
        end

        {
          "/rdf:RDF/@xml:lang" => false,
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title" => true,
          "/rdf:RDF/rdf:Description/dc:title/@xml:lang" => "de",
          "/rdf:RDF/rdf:Description/dc:title/text()" => "foo",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
  
      context "untyped as property if lang set and not default" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo"@de .
          )
          serialize(nt, attributes: :untyped, lang: "en-us")
        end

        {
          "/rdf:RDF/@xml:lang" => "en-us",
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title" => true,
          "/rdf:RDF/rdf:Description/dc:title/@xml:lang" => "de",
          "/rdf:RDF/rdf:Description/dc:title/text()" => "foo",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {})
          end
        end
      end
  
      context "multiple untyped attributes values through properties" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo"@de .
            <http://release/> <http://purl.org/dc/terms/title> "foo"@en-us .
          )
          serialize(nt, attributes: :untyped, lang: "en-us")
        end

        {
          "/rdf:RDF/@xml:lang" => "en-us",
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title" => true,
          #"/rdf:RDF/rdf:Description/dc:title/@xml:lang" => "de",
          "/rdf:RDF/rdf:Description/dc:title/text()" => "foo",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
  
      context "typed node as element if :untyped" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo"@^^<http://www.w3.org/2001/XMLSchema#string> .
          )
          serialize(nt, attributes: :untyped)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => %(foo)
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
  
      context "typed node as attribute if :typed" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo"@^^<http://www.w3.org/2001/XMLSchema#string> .
          )
          serialize(nt, attributes: :typed)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/@dc:title" => "foo",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
  
      context "multiple typed values through properties" do
        subject do
          nt = %(
            <http://release/> <http://purl.org/dc/terms/title> "foo"@^^<http://www.w3.org/2001/XMLSchema#string> .
            <http://release/> <http://purl.org/dc/terms/title> "bar"@^^<http://www.w3.org/2001/XMLSchema#string> .
          )
          serialize(nt, attributes: :untyped)
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "http://release/",
          "/rdf:RDF/rdf:Description/dc:title[contains(., 'foo')]" => %(<dc:title>foo</dc:title>),
          "/rdf:RDF/rdf:Description/dc:title[contains(., 'bar')]" => %(<dc:title>bar</dc:title>)
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
    end

    context "with namespace" do
      let(:nt) {%(
        <http://release/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://foo/Release> .
        <http://release/> <http://purl.org/dc/terms/title> "foo" .
        <http://release/> <http://foo/pred> <http://foo/obj> .
      )}

      context "default namespace" do
        subject do
          serialize(nt, default_namespace: "http://foo/",
                    prefixes: {foo: "http://foo/"})
        end

        {
          "/rdf:RDF/foo:Release/foo:pred/@rdf:resource" => "http://foo/obj",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {"foo" => "http://foo/"}, logger)
          end
        end

        specify { expect(subject).to match(/<Release/) }
        specify { expect(subject).to match(/<pred/) }
      end

      context "nil namespace" do
        subject do
          serialize(nt, prefixes: {"" => "http://foo/"})
        end

        {
          "/rdf:RDF/foo:Release/foo:pred/@rdf:resource" => "http://foo/obj",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {"foo" => "http://foo/"}, logger)
          end
        end

        specify { expect(subject).to match(/<Release/) }
        specify { expect(subject).to match(/<pred/) }
      end
    end
  
    describe "with base" do
      context "relative about URI" do
        subject do
          nt = %(
            <http://release/a> <http://foo/ref> <http://release/b> .
          )
          serialize(nt, attributes: :untyped, base_uri: "http://release/")
        end

        {
          "/rdf:RDF/rdf:Description/@rdf:about" => "a",
          "/rdf:RDF/rdf:Description/foo:ref/@rdf:resource" => "b"
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
    end
  
    context "with bnodes" do
      context "no nodeID attribute unless node is referenced as an object" do
        subject do
          nt = %(
            _:a <http://purl.org/dc/terms/title> "foo" .
          )
          serialize(nt, attributes: :untyped, base_uri: "http://release/")
        end

        {
          "/rdf:RDF/rdf:Description/@dc:title" => "foo",
          "/rdf:RDF/rdf:Description/@rdf:nodeID" => false
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end

      context "nodeID attribute if node is referenced as an object" do
        subject do
          nt = %(
            _:a <http://purl.org/dc/terms/title> "foo" .
            _:a <http://www.w3.org/2002/07/owl#sameAs> _:a .
          )
          serialize(nt, attributes: :untyped, base_uri: "http://release/")
        end

        {
          "/rdf:RDF/rdf:Description/@dc:title" => "foo",
          "/rdf:RDF/rdf:Description/@rdf:nodeID" => /a$/,
          "/rdf:RDF/rdf:Description/owl:sameAs/@rdf:nodeID" => /a$/
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            expect(subject).to have_xpath(path, value, {}, logger)
          end
        end
      end
      
      context "rdf:nodeID for forced BNode generation" do
        let(:statements) {
          parse(%(
            @prefix : <http://example/> .
            :foo :list (:bar (:baz)).
          ), format: :ttl)
        }
        subject do
          serialize(statements)
        end

        it "produces expected graph" do
          expect(parse(subject)).to be_equivalent_graph(statements, logger: logger)
        end
      end
    
      it "should not generate extraneous BNode" do
        statements = parse(%(
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
        ), format: :ttl)
        doc = serialize(statements)
        expect(parse(doc)).to be_equivalent_graph(statements, logger: logger)
      end
    end

    context "base direction" do
      {
        "base direction ltr": {
          input: %(<http://example/a> <http://example/b> "Hello"@en--ltr .),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2-basic",
            "/rdf:RDF/@its:version" => "2.0",
            "/rdf:RDF/rdf:Description/ns0:b/@xml:lang" => "en",
            "/rdf:RDF/rdf:Description/ns0:b/@its:dir" => "ltr",
            "/rdf:RDF/rdf:Description/ns0:b/text()" => "Hello",
          }
        },
        "base direction rtl": {
          input: %(<http://example/a> <http://example/b> "Hello"@en--rtl .),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2-basic",
            "/rdf:RDF/@its:version" => "2.0",
            "/rdf:RDF/rdf:Description/ns0:b/@xml:lang" => "en",
            "/rdf:RDF/rdf:Description/ns0:b/@its:dir" => "rtl",
            "/rdf:RDF/rdf:Description/ns0:b/text()" => "Hello",
          }
        },
        "unknown base direction": {
          input: %(<http://example/a> <http://example/b> "Hello"@en--unk .),
          exception: RDF::WriterError
        },
        "base direction LTR": {
          input: %(<http://example/a> <http://example/b> "Hello"@en--LTR .),
          exception: RDF::WriterError
        }
      }.each do |name, params|
        context name do
          let!(:graph) {RDF::Graph.new {|g| g << parse(params[:input], rdfstar: true, format: :ntriples)}}
          subject {serialize(graph)}

          if params[:exception]
            it "raises error" do
              expect {
                serialize(graph, validate: true)
              }.to raise_error(params[:exception])
            end
          else
            it "generates equivalent graph" do
              doc = parse(subject)
              expect(doc).to be_equivalent_graph(graph, logger: logger)
            end
          end

          params.fetch(:xpath, {}).each do |path, value|
            it "returns #{value.inspect} for xpath #{path}" do
              expect(subject).to have_xpath(path, value, {}, logger)
            end
          end
        end
      end
    end

    context "triple terms" do
      {
        "object-iii":  {
          input: %(<http://example/s> <http://example/p> <<(<http://example/s1> <http://example/p1> <http://example/o1>)>> .),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description/ns0:p/@rdf:parseType" => "Triple",
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description" => true,
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description/ns0:p1" => true,
          }
        },
        "object-iib":  {
          input: %(<http://example/s> <http://example/p> <<(<http://example/s1> <http://example/p1> _:o1)>> .),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description/ns0:p/@rdf:parseType" => "Triple",
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description" => true,
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description/ns0:p1" => true,
          }
        },
        "object-iil":  {
          input: %(<http://example/s> <http://example/p> <<(<http://example/s1> <http://example/p1> "o1")>> .),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description/ns0:p/@rdf:parseType" => "Triple",
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description" => true,
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description/ns0:p1" => true,
          }
        },
        "recursive-object": {
          input: %(<http://example/s> <http://example/p> <<(<http://example/s1> <http://example/p1> <<(<http://example/s2> <http://example/p2> <http://example/o2>)>>)>> .),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description/ns0:p/@rdf:parseType" => "Triple",
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description" => true,
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description/ns0:p1" => true,
          }
        },
        "two-objects": {
          input: %(
            <http://example/s> <http://example/p> <<(<http://example/s1> <http://example/p1> <http://example/o1>)>> .
            <http://example/s> <http://example/p> <<(<http://example/s2> <http://example/p2> <http://example/o2>)>> .
          ),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description/ns0:p/@rdf:parseType" => "Triple",
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description" => true,
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description/ns0:p1" => true,
            "/rdf:RDF/rdf:Description/ns0:p/rdf:Description/ns0:p2" => true,
          }
        }
      }.each do |name, params|
        context name do
          let!(:graph) {RDF::Graph.new {|g| g << parse(params[:input], rdfstar: true, format: :ntriples)}}
          subject {serialize(graph)}

          it "generates equivalent graph" do
            doc = parse(subject)
            expect(doc).to be_equivalent_graph(graph, logger: logger)
          end

          params.fetch(:xpath, {}).each do |path, value|
            it "returns #{value.inspect} for xpath #{path}" do
              expect(subject).to have_xpath(path, value, {}, logger)
            end
          end
        end
      end
    end

    context "annotations" do
      {
        'turtle-star-annotation-1' => {
          input: %(
            PREFIX : <http://example/>
            :s :p :o {| :r :z |} .
          ),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p" => true,
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:resource" => 'http://example/o',
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:annotationNodeID" => %r(\w+),

            "/rdf:RDF/rdf:Description[@rdf:nodeID]/rdf:reifies" => false,
            "/rdf:RDF/rdf:Description[@rdf:nodeID]/ns0:r/@rdf:resource" => 'http://example/z',
          }
        },
        'IRI reifier' => {
          input: %(
            PREFIX : <http://example/>
            :s :p :o ~:id {| :r :z |} .
          ),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p" => true,
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:resource" => 'http://example/o',
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:annotation" => 'http://example/id',

            "/rdf:RDF/rdf:Description[@rdf:about]/rdf:reifies" => false,
            "/rdf:RDF/rdf:Description[@rdf:about]/ns0:r/@rdf:resource" => 'http://example/z',
          }
        },
        'BNode reifier' => {
          input: %(
            PREFIX : <http://example/>
            :s :p :o ~ _:id {| :r :z |} .
          ),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p" => true,
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:resource" => 'http://example/o',
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:annotationNodeID" => 'id',

            "/rdf:RDF/rdf:Description[@rdf:nodeID]/rdf:reifies" => false,
            "/rdf:RDF/rdf:Description[@rdf:nodeID]/ns0:r/@rdf:resource" => 'http://example/z',
          }
        },
        'BNode reifier used as object' => {
          input: %(
            PREFIX : <http://example/>
            :s :p :o ~ _:id {| :r :z |} .
            :s1 :p1 _:id .
          ),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p" => true,
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:resource" => 'http://example/o',
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:annotationNodeID" => 'id',

            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s1']/ns0:p1/rdf:Description/@rdf:nodeID" => "id",
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s1']/ns0:p1/rdf:Description/ns0:r" => true,
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s1']/ns0:p1/rdf:Description/ns0:r/@rdf:resource" => "http://example/z",
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s1']/ns0:p1/rdf:Description/ns0:r/rdf:reifies" => false,
          }
        },
        'turtle-star-annotation-2' => {
          input: %(
            PREFIX :       <http://example/>
            PREFIX xsd:     <http://www.w3.org/2001/XMLSchema#>

            :s :p :o {| :source [ :graph <http://host1/> ;
                                  :date "2020-01-20"^^xsd:date
                                ] ;
                        :source [ :graph <http://host2/> ;
                                  :date "2020-12-31"^^xsd:date
                                ]
                      |} .
          ),
          xpath: {
            "/rdf:RDF/@rdf:version" => "1.2",
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p" => true,
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:resource" => 'http://example/o',
            "/rdf:RDF/rdf:Description[@rdf:about='http://example/s']/ns0:p/@rdf:annotationNodeID" => %r(\w+),
            "/rdf:RDF/rdf:Description[@rdf:nodeID]/ns0:graph[@rdf:resource='http://host1/]" => true,
            "/rdf:RDF/rdf:Description[@rdf:nodeID]/ns0:graph[@rdf:resource='http://host2/]" => true,
            "/rdf:RDF/rdf:Description[@rdf:nodeID]/ns0:source" => true,
          }
        }
      }.each do |name, params|
        context name do
          let!(:graph) {RDF::Graph.new {|g| g << parse(params[:input], rdfstar: true, format: :ttl)}}
          subject {serialize(graph)}

          it "generates equivalent graph" do
            logger.info("rendered:" + subject)
            result = parse(subject)
            expect(result).to be_equivalent_graph(graph, logger: logger)
          end

          params.fetch(:xpath, {}).each do |path, value|
            it "returns #{value.inspect} for xpath #{path}" do
              logger.info("rendered:" + subject)
              expect(subject).to have_xpath(path, value, {}, logger)
            end
          end
        end
      end
    end

    describe "with a stylesheet" do
      subject do
        nt = %(
            <http://release/a> <http://foo/ref> <http://release/b> .
        )
        serialize(nt, stylesheet: "/path/to/rdfxml.xsl")
      end

      it "should have a stylesheet as a processing instruction in the second line of the XML" do
        lines = subject.split(/[\r\n]+/)
        expect(lines[1]).to eq '<?xml-stylesheet type="text/xsl" href="/path/to/rdfxml.xsl"?>'
      end
    end
  
    describe "illegal RDF values" do
      it "raises error with literal as subject" do
        statements = [RDF::Statement(RDF::Literal.new("literal"), RDF::URI("http://purl.org/dc/terms/title"), RDF::Literal.new("foo"))].extend(RDF::Enumerable)
        expect { serialize(statements, validate: true) }.to raise_error(RDF::WriterError)
      end
      it "raises error with node as predicate" do
        statements = [RDF::Statement(RDF::URI("http://example.com"), RDF::Node.new, RDF::Literal.new("foo"))].extend(RDF::Enumerable)
        expect { serialize(statements, validate: true) }.to raise_error(RDF::WriterError)
      end
    end

    describe "reported issues" do
      {
        "issue #31 with namespaces" => [
          %(<http://example.com/> <http://www.w3.org/1999/xhtml/vocab#license> <http://creativecommons.org/licenses/by-sa/3.0/> .),
          {xhv: 'http://www.w3.org/1999/xhtml/vocab#'},
          {
            "/rdf:RDF/rdf:Description/@rdf:about" => 'http://example.com/',
            "/rdf:RDF/rdf:Description/xhv:license/@rdf:resource" => 'http://creativecommons.org/licenses/by-sa/3.0/'
          }
        ]
      }.each do |test, (input, prefixes, paths)|
        it test do
          statements = parse(input, format: :ntriples)
          result = serialize(statements, prefixes: prefixes, standard_prefixes: false)
          paths.each do |path, value|
            expect(result).to have_xpath(path, value, {}, logger)
          end
        end
      end
    end

    # W3C RDF/XML Test suite from https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-xml/tests/
    describe "w3c RDF/XML tests" do
      require 'suite_helper'
      %w(rdf11/rdf-xml/manifest.ttl).each do |man|
        Fixtures::SuiteTest::Manifest.open(Fixtures::SuiteTest::BASE + man) do |m|
          describe m.comment do
            m.entries.each do |t|
              next unless t.positive_test? && t.evaluate?
              specify "#{t.name}" do
                unless defined?(::Nokogiri)
                  pending("XML-C14XL") if t.name == "xml-canon-test001"
                end
                statements = parse(t.expected, base_uri: t.base, format: :ntriples)

                serialized = serialize(statements, format: :rdfxml, base_uri: t.base)
                logger.info "serialized: #{serialized}"
                expect(parse(serialized, base_uri: t.base)).to be_equivalent_graph(statements, logger: logger)
              end
            end
          end
        end
      end
    end unless ENV['CI'] # Not for continuous integration

    def parse(input, **options)
      reader_class = RDF::Reader.for(options.fetch(:format, :rdfxml))

      reader_class.new(input, **options, &:each).to_a.extend(RDF::Enumerable)
    end

    # Serialize ntstr to a string and compare against regexps
    def serialize(ntstr, **options)
      g = ntstr.is_a?(RDF::Enumerable) ? ntstr : parse(ntstr, format: :ntriples, validate: false, logger: [])
      logger.info "serialized: #{ntstr}"
      result = RDF::RDFXML::Writer.buffer(
        logger:   logger,
        standard_prefixes: true,
        encoding: Encoding::UTF_8,
        **options
      ) do |writer|
        writer << g
      end
      require 'cgi'
      result
    end
  end
end