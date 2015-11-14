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
require 'open-uri/cached'
begin
  require 'nokogiri'
rescue LoadError => e
  :rexml
end
require 'rdf/rdfxml'

# Create and maintain a cache of downloaded URIs
URI_CACHE = File.expand_path(File.join(File.dirname(__FILE__), "uri-cache"))
Dir.mkdir(URI_CACHE) unless File.directory?(URI_CACHE)
OpenURI::Cache.class_eval { @cache_path = URI_CACHE }

::RSpec.configure do |c|
  c.filter_run focus: true
  c.run_all_when_everything_filtered = true
  c.include(RDF::Spec::Matchers)
end
