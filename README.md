# RDF::RDFXML reader/writer

[RDF/XML][RDF/XML] parser for [RDF.rb][RDF.rb].

## DESCRIPTION

RDF::RDFXML is an [RDF/XML][RDF/XML] reader/writer for Ruby using the [RDF.rb][RDF.rb] library suite.

## FEATURES
RDF::RDFXML parses [RDF/XML][RDF/XML] into statements or triples and serializes triples, statements or graphs.

Fully compliant [RDF/XML][RDF/XML] parser and serializer.

Install with `gem install rdf-rdfxml`

## Usage:
Instantiate a parser and parse source, specifying type and base-URL

    RDF::RDFXML::Reader.open("./etc/doap.xml") do |reader|
      reader.each_statement do |statement|
        puts statement.inspect
      end
    end

## Dependencies
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 0.3.1)
* [Nokogiri](http://rubygems.org/gems/nokogiri) (>= 1.4.4)

## Documentation
Full documentation available on [RubyForge](http://rdf.rubyforge.org/rdfxml)

### Principle Classes
* {RDF::RDFXML}
* {RDF::RDFXML::Format}
* {RDF::RDFXML::Reader}
* {RDF::RDFXML::Writer}

### Additional vocabularies
* {RDF::XML}

### Patches
* {Array}
* {RDF::Graph}
* {RDF::Literal::XML}
* {Nokogiri::XML::Node}

## TODO
* Add support for LibXML and REXML bindings, and use the best available
* Consider a SAX-based parser for improved performance

## Resources
* [RDF.rb][RDF.rb]
* [RDF/XML][RDF/XML]
* [Distiller](http://distiller.kellogg-assoc)
* [Documentation](http://rdf.rubyforge.org/rdfxml)
* [History](file:file.History.html)
* [RDF Tests](http://www.w3.org/2000/10/rdf-tests/rdfcore/allTestCases.html)

## AUTHOR
* [Gregg Kellogg](http://github.com/gkellogg) - <http://kellogg-assoc.com/>

## CONTRIBUTORS
* [Nicholas Humfrey](http://github.com/njh)

## License

This is free and unencumbered public domain software. For more information,
see <http://unlicense.org/> or the accompanying {file:UNLICENSE} file.

## FEEDBACK

* gregg@kellogg-assoc.com
* <http://rubygems.org/rdf-rdfxml>
* <http://github.com/gkellogg/rdf-rdfxml>
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

[RDF.rb]:   http://rdf.rubyforge.org/
[RDF/XML]:  http://www.w3.org/TR/REC-rdf-syntax/  "RDF/XML Syntax Specification"
