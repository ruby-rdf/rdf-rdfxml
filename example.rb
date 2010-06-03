#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'rubygems'
require 'rdf/rdfxml'

data = <<-EOF;
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

RDF::RDFXML::Reader.new(data, :base_uri => 'http://example.org/example.xml') do |reader|
  reader.each_statement do |statement|
    statement.inspect!
  end
end
