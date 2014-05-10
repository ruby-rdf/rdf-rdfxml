#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = %q{rdf-rdfxml}
  gem.homepage              = %q{http://ruby-rdf.github.com/rdf-rdfxml}
  gem.license               = 'Public Domain' if gem.respond_to?(:license=)
  gem.summary               = %q{RDF/XML reader/writer for RDF.rb.}
  gem.description           = %q{RDF::RDFXML is an RDF/XML reader and writer for the RDF.rb library suite.}
  gem.rubyforge_project     = 'rdf-rdfxml'

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(README.md History.md AUTHORS CONTRIBUTORS VERSION UNLICENSE) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 1.9.3'
  gem.requirements          = []

  gem.add_runtime_dependency     'rdf',             '~> 1.1'
  gem.add_runtime_dependency     'rdf-rdfa',        '~> 1.1'
  gem.add_runtime_dependency     'rdf-xsd',         '~> 1.1'

  #gem.add_development_dependency 'nokogiri' ,       '>= 1.6.1' # conditionally done in Gemfile
  gem.add_development_dependency 'equivalent-xml' , '~> 0.2'
  gem.add_development_dependency 'open-uri-cached', '~> 0.0', '>= 0.0.5'
  gem.add_development_dependency 'spira',           '= 0.0.12'
  gem.add_development_dependency 'json-ld',         '~> 1.1'
  gem.add_development_dependency 'rspec',           '~> 2.14'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 1.1'
  gem.add_development_dependency 'rdf-turtle',      '~> 1.1'
  gem.add_development_dependency 'rdf-spec',        '~> 1.1'
  gem.add_development_dependency 'yard' ,           '~> 0.8'

  # Rubinius has it's own dependencies
  if RUBY_ENGINE == "rbx" && RUBY_VERSION >= "2.1.0"
     gem.add_runtime_dependency     "racc"
  end

  gem.post_install_message  = nil
end

