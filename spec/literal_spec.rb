require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::Literal do
  describe "XML Literal" do
    describe "with no namespace" do
      subject { RDF::Literal.new("foo <sup>bar</sup> baz!", :datatype => RDF["XMLLiteral"]) }
      it "should indicate xmlliteral?" do
        subject.xmlliteral?.should == true
      end
      
      it "should return normalized literal" do subject.value.should == "foo <sup>bar</sup> baz!" end
    end
      
    describe "with a namespace" do
      subject {
        RDF::Literal.xmlliteral("foo <sup>bar</sup> baz!", :namespaces => {"dc" => "http://purl.org/dc/terms/"})
      }
    
      it "should return normalized literal" do subject.value.should == "foo <sup>bar</sup> baz!" end
      
      describe "and language" do
        subject {
          RDF::Literal.xmlliteral("foo <sup>bar</sup> baz!", :namespaces => {"dc" => "http://purl.org/dc/terms/"}, :language => "fr")
        }

        it "should return normalized literal" do subject.value.should == "foo <sup xml:lang=\"fr\">bar</sup> baz!" end
      end
      
      describe "and language with an existing language embedded" do
        subject {
          RDF::Literal.xmlliteral("foo <sup>bar</sup><sub xml:lang=\"en\">baz</sub>", :namespaces => {}, :language => "fr")
        }

        it "should return normalized literal" do subject.value.should == "foo <sup xml:lang=\"fr\">bar</sup><sub xml:lang=\"en\">baz</sub>" end
      end
      
      describe "and namespaced element" do
        subject {
          root = Nokogiri::XML.parse(%(
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
          <html xmlns="http://www.w3.org/1999/xhtml"
                xmlns:dc="http://purl.org/dc/terms/"
          	  xmlns:ex="http://example.org/rdf/"
          	  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
          	  xmlns:svg="http://www.w3.org/2000/svg">
          	<head profile="http://www.w3.org/1999/xhtml/vocab http://www.w3.org/2005/10/profile">
          		<title>Test 0100</title>
          	</head>
            <body>
            	<div about="http://www.example.org">
                <h2 property="ex:example" datatype="rdf:XMLLiteral"><svg:svg/></h2>
          	</div>
            </body>
          </html>
          ), nil, nil, Nokogiri::XML::ParseOptions::DEFAULT_XML).root
          content = root.css("h2").children
          RDF::Literal.xmlliteral(content, :namespaces => {:svg => "http://www.w3.org/2000/svg", :dc => "http://purl.org/dc/terms"})
        }
        it "should add namespace" do subject.value.should == "<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"></svg:svg>" end
      end
      
      describe "and existing namespace definition" do
        subject {
          RDF::Literal.xmlliteral("<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"/>", :namespaces => {"svg" => "http://www.w3.org/2000/svg"})
        }
        it "should add namespace" do subject.value.should == "<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"></svg:svg>" end
      end
    end
      
    describe "with a default namespace" do
      subject {
        RDF::Literal.xmlliteral("foo <sup>bar</sup> baz!", :namespaces => {"" => "http://purl.org/dc/terms/"})
      }
    
      it "should return normalized literal foo" do subject.value.should == "foo <sup xmlns=\"http://purl.org/dc/terms/\">bar</sup> baz!" end
    end
    
    describe "with <br/>" do
      subject {
        RDF::Literal.xmlliteral("<br/>")
      }
      it "should add namespace" do subject.value.should == "<br></br>" end
    end
  end
end