#!/usr/bin/env ruby
require 'rubygems'
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", 'lib')))
require "bundler/setup"
require 'rdf/rdfxml'

class Foo < RDF::Vocabulary('http://example.com#')
  property :hasList
end

g = RDF::Graph.new
u = RDF::URI.new('info:fedora/999')

list1 = RDF::Node.new
list2 = RDF::Node.new

leaf1 = RDF::Node.new
leaf2 = RDF::Node.new

g.insert([leaf1, RDF::URI("http://purl.org/dc/terms/title"), 'Hi'   ])
g.insert([leaf2, RDF::URI("http://purl.org/dc/terms/title"), 'There'])
g.insert([list1,  RDF.first,     leaf1  ])
g.insert([list1,  RDF.rest,      list2  ])
g.insert([list2,  RDF.first,     leaf2  ])
g.insert([list2,  RDF.rest,      RDF.nil])
g.insert([u,     Foo.hasList,   list1   ])

puts g.dump(:rdfxml)
puts g.dump(:ntriples)
