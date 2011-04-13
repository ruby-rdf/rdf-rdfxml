require 'rubygems'
require 'yard'

begin
  gem 'jeweler'
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "rdf-rdfxml"
    gemspec.summary = "RDF/XML reader/writer for RDF.rb."
    gemspec.description = %q(RDF::RDFXML is an RDF/XML reader and writer for the RDF.rb library suite.)
    gemspec.email = "gregg@kellogg-assoc.com"
    gemspec.homepage = "http://github.com/gkellogg/rdf-rdfxml"
    gemspec.authors = ["Gregg Kellogg"]
    gemspec.add_dependency('rdf', '>= 0.3.3')
    gemspec.add_dependency('nokogiri', '>= 1.4.4')
    gemspec.add_development_dependency('open-uri-cached')
    gemspec.add_development_dependency('spira', '>= 0.0.12')
    gemspec.add_development_dependency('rspec', '>= 2.5.0')
    gemspec.add_development_dependency('rdf-spec', '>= 0.3.3')
    gemspec.add_development_dependency('rdf-isomorphic', '>= 0.3.4')
    gemspec.add_development_dependency('yard', '>= 0.6.4')
    gemspec.extra_rdoc_files     = %w(README.md History.rdoc AUTHORS CONTRIBUTORS UNLICENSE)
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
end

desc "Generate HTML report specs"
RSpec::Core::RakeTask.new("doc:spec") do |spec|
  spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
end

YARD::Rake::YardocTask.new

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

task :default => :spec
