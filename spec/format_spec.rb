require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::RDFXML::Format do
  context "descovery" do
    {
      "rdf" => RDF::Format.for(:rdf),
      "xml" => RDF::Format.for(:xml),
      "etc/foaf.xml" => RDF::Format.for("etc/foaf.xml"),
      "etc/foaf.rdf" => RDF::Format.for("etc/foaf.rdf"),
      "foaf.xml" => RDF::Format.for(:file_name      => "foaf.xml"),
      "foaf.rdf" => RDF::Format.for(:file_name      => "foaf.xml"),
      ".xml" => RDF::Format.for(:file_extension => "xml"),
      ".rdf" => RDF::Format.for(:file_extension => "rdf"),
      "application/xml" => RDF::Format.for(:content_type   => "application/xml"),
      "application/rdf+xml" => RDF::Format.for(:content_type   => "application/rdf+xml"),
    }.each_pair do |label, format|
      it "should discover '#{label}'" do
        format.should == RDF::RDFXML::Format
      end
    end
  end
end
