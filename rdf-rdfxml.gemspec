#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

begin
  RUBY_ENGINE
rescue NameError
  RUBY_ENGINE = "ruby"  # Not defined in Ruby 1.8.7
end

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = %q{rdf-rdfxml}
  gem.homepage              = %q{http://github.com/gkellogg/rdf-rdfxml}
  gem.license               = 'Public Domain' if gem.respond_to?(:license=)
  gem.summary               = %q{RDF/XML reader/writer for RDF.rb.}
  gem.description           = %q{RDF::RDFXML is an RDF/XML reader and writer for the RDF.rb library suite.}
  gem.rubyforge_project     = 'rdf-rdfxml'

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(README.markdown History.markdown AUTHORS CONTRIBUTORS VERSION UNLICENSE) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 1.8.1'
  gem.requirements          = []

  gem.add_runtime_dependency     'rdf',             '>= 0.3.4'
  gem.add_runtime_dependency     'rdf-xsd',         '>= 0.3.5'

  gem.add_development_dependency 'nokogiri' ,       '>= 1.5.0'
  gem.add_development_dependency 'equivalent-xml' , '>= 0.2.8'
  gem.add_development_dependency 'open-uri-cached', '>= 0.0.4'
  gem.add_development_dependency 'spira',           '>= 0.0.12'
  gem.add_development_dependency 'rspec',           '>= 2.5.0'
  gem.add_development_dependency 'rdf-isomorphic',  '>= 0.3.4'
  gem.add_development_dependency 'rdf-n3',          '>= 0.3.4'
  gem.add_development_dependency 'rdf-spec',        '>= 0.3.4'
  gem.add_development_dependency 'yard' ,           '>= 0.6.0'
  gem.post_install_message  = nil
end

