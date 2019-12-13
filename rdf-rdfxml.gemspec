#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = %q{rdf-rdfxml}
  gem.homepage              = %q{http://ruby-rdf.github.com/rdf-rdfxml}
  gem.license               = 'Unlicense'
  gem.summary               = %q{RDF/XML reader/writer for RDF.rb.}
  gem.description           = %q{RDF::RDFXML is an RDF/XML reader and writer for the RDF.rb library suite.}

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(README.md History.md AUTHORS CONTRIBUTORS VERSION UNLICENSE) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)

  gem.required_ruby_version = '>= 2.4'
  gem.requirements          = []

  gem.add_runtime_dependency     'rdf',             '~> 3.1'
  gem.add_runtime_dependency     'rdf-xsd',         '~> 3.0'
  gem.add_runtime_dependency     'rdf-rdfa',        '~> 3.0'
  gem.add_runtime_dependency     'htmlentities',    '~> 4.3'

  #gem.add_development_dependency 'nokogiri' ,       '~> 1.8'
  #gem.add_development_dependency 'equivalent-xml' , '~> 0.6' # conditionally done in Gemfile
  gem.add_development_dependency 'open-uri-cached', '~> 0.0', '>= 0.0.5'
  gem.add_development_dependency 'spira',           '= 0.0.12'
  #gem.add_development_dependency 'json-ld',         '~> 3.0'
  gem.add_development_dependency 'json-ld',         '>= 3.1'
  gem.add_development_dependency 'rspec',           '~> 3.9'
  gem.add_development_dependency 'rspec-its',       '~> 1.3'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 3.0'
  gem.add_development_dependency 'rdf-turtle',      '~> 3.1'
  gem.add_development_dependency 'rdf-spec',        '~> 3.1'
  gem.add_development_dependency 'rdf-vocab',       '~> 3.0'
  gem.add_development_dependency 'yard' ,           '~> 0.9.20'

  gem.post_install_message  = nil
end

