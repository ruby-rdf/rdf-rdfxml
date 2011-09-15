#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = %q{rdf-rdfxml}
  gem.version               = "0.3.4"
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

  gem.add_dependency             'rdf',             '>= 0.3.4'
  gem.add_runtime_dependency     'nokogiri',        '>= 1.4.4'
  gem.add_development_dependency 'open-uri-cached'
  gem.add_development_dependency 'spira',           '>= 0.0.12'
  gem.add_development_dependency 'rspec',           '>= 2.5.0'
  gem.add_development_dependency 'rdf-spec',        '>= 0.3.4'
  gem.add_development_dependency 'yard' ,           '>= 0.6.0'
  gem.post_install_message  = nil
end

