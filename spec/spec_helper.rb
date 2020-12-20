$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)

require "bundler/setup"
require 'rspec'
require 'rdf/isomorphic'
require 'rdf/ntriples'
require 'rdf/turtle'
require 'rdf/spec'
require 'rdf/spec/matchers'
require 'matchers'
begin
  require 'nokogiri'
rescue LoadError => e
  :rexml
end
begin
  require 'simplecov'
  require 'coveralls'
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/lib/rdf/rdfa/reader/rexml.rb"
    add_filter "/lib/rdf/rdfa/context.rb"
  end
rescue LoadError
end
require 'rdf/rdfxml'

::RSpec.configure do |c|
  c.filter_run focus: true
  c.run_all_when_everything_filtered = true
  c.include(RDF::Spec::Matchers)
end
