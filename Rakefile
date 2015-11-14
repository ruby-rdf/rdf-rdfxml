require 'rubygems'
require 'rubygems'
require 'yard'
require 'rspec/core/rake_task'

namespace :gem do
  desc "Build the rdf-rdfxml-#{File.read('VERSION').chomp}.gem file"
  task :build do
    sh "gem build rdf-rdfxml.gemspec && mv rdf-rdfxml-#{File.read('VERSION').chomp}.gem pkg/"
  end

  desc "Release the rdf-rdfxml-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push pkg/rdf-rdfxml-#{File.read('VERSION').chomp}.gem"
  end
end

RSpec::Core::RakeTask.new(:spec)

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
end

namespace :doc do
  YARD::Rake::YardocTask.new

  desc "Generate HTML report specs"
  RSpec::Core::RakeTask.new("spec") do |spec|
    spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
  end
end

desc "Generate RDF Core Manifest.yml"
namespace :spec do
  task :prepare do
    $:.unshift(File.join(File.dirname(__FILE__), 'lib'))
    require 'rdf/rdfxml'
    require 'spec/rdf_helper'
    require 'fileutils'

    yaml = File.join(RDFCORE_DIR, "Manifest.yml")
    FileUtils.rm_f(yaml)
    RdfHelper::TestCase.to_yaml(RDFCORE_TEST, RDFCORE_DIR, yaml)
  end
end

task specs: :spec
task default: :spec


desc "Generate etc/doap.{nt,ttl} from etc/doap.html."
task :doap do
  require 'rdf/rdfxml'
  require 'rdf/turtle'
  require 'rdf/ntriples'
  g = RDF::Graph.load("etc/doap.rdf")
  RDF::NTriples::Writer.open("etc/doap.nt") {|w| w <<g }
  RDF::Turtle::Writer.open("etc/doap.ttl", standard_prefixes: true) {|w| w <<g }
end
