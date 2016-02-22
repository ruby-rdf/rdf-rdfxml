# RDF::RDFXML reader/writer 

[RDF/XML][] reader/writer for [RDF.rb][].

[![Gem Version](https://badge.fury.io/rb/rdf-rdfxml.png)](http://badge.fury.io/rb/rdf-rdfxml)
[![Build Status](https://secure.travis-ci.org/ruby-rdf/rdf-rdfxml.png?branch=master)](http://travis-ci.org/ruby-rdf/rdf-rdfxml)

## DESCRIPTION

RDF::RDFXML is an [RDF/XML][RDF/XML] reader/writer for [Ruby][] using the [RDF.rb][RDF.rb] library suite.

## FEATURES
RDF::RDFXML parses [RDF/XML][] into statements or triples and serializes triples, statements or graphs. It also serializes graphs to [RDF/XML][].

Fully compliant [RDF/XML][] parser and serializer.

Install with `gem install rdf-rdfxml`

* 100% free and unencumbered [public domain](http://unlicense.org/) software.
* Implements a complete parser for [RDF/XML][].
* Compatible with Ruby >= 2.0.

## Usage:
Instantiate a parser and parse source, specifying type and base-URL

    RDF::RDFXML::Reader.open("./etc/doap.xml") do |reader|
      reader.each_statement do |statement|
        puts statement.inspect
      end
    end

Define `xml:base` and `xmlns` definitions, and use for serialization using `:base_uri` an `:prefixes` options.

Canonicalize and validate using `:canonicalize` and `:validate` options.

Write a graph to a file:

    RDF::RDFXML::Writer.open("etc/test.ttl") do |writer|
       writer << graph
    end

## Dependencies
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 2.0)
* Soft dependency on [Nokogiri](http://rubygems.org/gems/nokogiri) (>= 1.6.0)

## Documentation
Full documentation available on [Rubydoc.info][RDF/XML doc])

### Principle Classes
* {RDF::RDFXML}
* {RDF::RDFXML::Format}
* {RDF::RDFXML::Reader}
* {RDF::RDFXML::Writer}

### Additional vocabularies
* {RDF::XML}

## TODO
* Consider a SAX-based parser for improved performance

## Resources
* [RDF.rb][RDF.rb]
* [RDF/XML][RDF/XML]
* [Distiller](http://rdf.greggkellogg.net)
* [Documentation][RDF/XML doc]
* [RDF Tests](http://www.w3.org/2000/10/rdf-tests/rdfcore/allTestCases.html)

## Author
* [Gregg Kellogg](http://github.com/gkellogg) - <http://greggkellogg.net/>

## Contributors
* [Nicholas Humfrey](http://github.com/njh) - <http://njh.me/>

## Contributing
This repository uses [Git Flow](https://github.com/nvie/gitflow) to mange development and release activity. All submissions _must_ be on a feature branch based on the _develop_ branch to ease staging and integration.

* Do your best to adhere to the existing coding conventions and idioms.
* Don't use hard tabs, and don't leave trailing whitespace on any line.
* Do document every method you add using [YARD][] annotations. Read the
  [tutorial][YARD-GS] or just look at the existing code for examples.
* Don't touch the `.gemspec`, `VERSION` or `AUTHORS` files. If you need to
  change them, do so on your private branch only.
* Do feel free to add yourself to the `CREDITS` file and the corresponding
  list in the the `README`. Alphabetical order applies.
* Do note that in order for us to merge any non-trivial changes (as a rule
  of thumb, additions larger than about 15 lines of code), we need an
  explicit [public domain dedication][PDD] on record from you.

## License

This is free and unencumbered public domain software. For more information,
see <http://unlicense.org/> or the accompanying {file:UNLICENSE} file.

## FEEDBACK

* gregg@greggkellogg.net
* <http://rubygems.org/rdf-rdfxml>
* <http://github.com/ruby-rdf/rdf-rdfxml>
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

[Ruby]:         http://ruby-lang.org/
[RDF]:          http://www.w3.org/RDF/
[RDF.rb]:       http://rubygems.org/gems/rdf
[RDF/XML]:      hhttp://www.w3.org/TR/rdf-syntax-grammar/ "RDF/XML Syntax Specification"
[YARD]:         http://yardoc.org/
[YARD-GS]:      http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
[PDD]:          http://lists.w3.org/Archives/Public/public-rdf-ruby/2010May/0013.html
[RDF/XML doc]:  http://rubydoc.info/github/ruby-rdf/rdf-rdfxml/master/frames