# coding: utf-8
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'nokogiri'

describe RDF::Literal do
  require 'nokogiri' rescue nil

  before :each do 
    @new = Proc.new { |*args| RDF::Literal.new(*args) }
  end

  describe "XML Literal" do
    describe "with no namespace" do
      subject { @new.call("foo <sup>bar</sup> baz!", :datatype => RDF.XMLLiteral) }
      it "should return input" do subject.to_s.should == "foo <sup>bar</sup> baz!" end

      it "should be equal if they have the same contents" do
        should == @new.call("foo <sup>bar</sup> baz!", :datatype => RDF.XMLLiteral)
      end
    end

    describe "with a namespace" do
      subject {
        @new.call("foo <dc:sup>bar</dc:sup> baz!", :datatype => RDF.XMLLiteral,
                      :namespaces => {"dc" => RDF::DC.to_s})
      }

      it "should add namespaces" do subject.to_s.should == "foo <dc:sup xmlns:dc=\"http://purl.org/dc/terms/\">bar</dc:sup> baz!" end

      describe "and language" do
        subject {
          @new.call("foo <dc:sup>bar</dc:sup> baz!", :datatype => RDF.XMLLiteral,
                        :namespaces => {"dc" => RDF::DC.to_s},
                        :language => :fr)
        }

        it "should add namespaces and language" do subject.to_s.should == "foo <dc:sup xmlns:dc=\"http://purl.org/dc/terms/\" xml:lang=\"fr\">bar</dc:sup> baz!" end
      end

      describe "and language with an existing language embedded" do
        subject {
          @new.call("foo <dc:sup>bar</dc:sup><dc:sub xml:lang=\"en\">baz</dc:sub>",
                        :datatype => RDF.XMLLiteral,
                        :namespaces => {"dc" => RDF::DC.to_s},
                        :language => :fr)
        }

        it "should add namespaces and language" do subject.to_s.should == "foo <dc:sup xmlns:dc=\"http://purl.org/dc/terms/\" xml:lang=\"fr\">bar</dc:sup><dc:sub xmlns:dc=\"http://purl.org/dc/terms/\" xml:lang=\"en\">baz</dc:sub>" end
      end
    end

    describe "with a default namespace" do
      subject {
        @new.call("foo <sup>bar</sup> baz!", :datatype => RDF.XMLLiteral,
                      :namespaces => {"" => RDF::DC.to_s})
      }

      it "should add namespace" do subject.to_s.should == "foo <sup xmlns=\"http://purl.org/dc/terms/\">bar</sup> baz!" end
    end
    
    context "rdfcore tests" do
      context "rdfms-xml-literal-namespaces" do
        it "should reproduce test001" do
          l = @new.call("
      <html:h1>
        <b>John</b>
      </html:h1>
   ",
                      :datatype => RDF.XMLLiteral,
                      :namespaces => {
                        "" => "http://www.w3.org/1999/xhtml",
                        "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
                        "html" => "http://NoHTML.example.org",
                        "my" => "http://my.example.org/",
                      })

          l.to_s.should == "\n      <html:h1 xmlns:html=\"http://NoHTML.example.org\">\n        <b xmlns=\"http://www.w3.org/1999/xhtml\">John</b>\n      </html:h1>\n   "
        end

        it "should reproduce test002" do
          l = @new.call("
    Ramifications of
       <apply>
      <power/>
      <apply>
	<plus/>
	<ci>a</ci>
	<ci>b</ci>
      </apply>
      <cn>2</cn>
    </apply>
    to World Peace
  ",
                      :datatype => RDF.XMLLiteral,
                      :namespaces => {
                        "" => "http://www.w3.org/TR/REC-mathml",
                      })

          l.to_s.should == "\n    Ramifications of\n       <apply xmlns=\"http://www.w3.org/TR/REC-mathml\">\n      <power></power>\n      <apply>\n\t<plus></plus>\n\t<ci>a</ci>\n\t<ci>b</ci>\n      </apply>\n      <cn>2</cn>\n    </apply>\n    to World Peace\n  "
        end
      end

      context "rdfms-xmllang" do
        it "should reproduce test001" do
          l = @new.call("chat", :datatype => RDF.XMLLiteral, :language => nil)

          l.to_s.should == "chat"
        end
        it "should reproduce test002" do
          l = @new.call("chat", :datatype => RDF.XMLLiteral, :language => :fr)

          l.to_s.should == "chat"
        end
      end

      context "xml-canon" do
        it "should reproduce test001" do
          l = @new.call("<br />", :datatype => RDF.XMLLiteral)

          l.to_s.should == "<br></br>"
        end
      end
    end
  end if defined?(::Nokogiri)
end
