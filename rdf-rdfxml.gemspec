#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = %q{rdf-rdfxml}
  gem.homepage              = %q{https://github.com/ruby-rdf/rdf-rdfxml}
  gem.license               = 'Unlicense'
  gem.summary               = %q{RDF/XML reader/writer for RDF.rb.}
  gem.description           = %q{RDF::RDFXML is an RDF/XML reader and writer for the RDF.rb library suite.}
  gem.metadata           = {
    "documentation_uri" => "https://ruby-rdf.github.io/rdf-rdfxml",
    "bug_tracker_uri"   => "https://github.com/ruby-rdf/rdf-rdfxml/issues",
    "homepage_uri"      => "https://github.com/ruby-rdf/rdf-rdfxml",
    "mailing_list_uri"  => "https://lists.w3.org/Archives/Public/public-rdf-ruby/",
    "source_code_uri"   => "https://github.com/ruby-rdf/rdf-rdfxml",
  }

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(README.md History.md AUTHORS CONTRIBUTORS VERSION UNLICENSE) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)

  gem.required_ruby_version = '>= 3.0'
  gem.requirements          = []

  gem.add_runtime_dependency     'rdf',             '~> 3.3'
  gem.add_runtime_dependency     'rdf-xsd',         '~> 3.3'
  gem.add_runtime_dependency     'htmlentities',    '~> 4.3'
  gem.add_runtime_dependency     'builder',         '~> 3.2', '>= 3.2.4'

  gem.add_development_dependency 'getoptlong',      '~> 0.2'
  gem.add_development_dependency 'json-ld',         '>= 3.3'
  gem.add_development_dependency 'rspec',           '~> 3.12'
  gem.add_development_dependency 'rspec-its',       '~> 1.3'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 3.3'
  gem.add_development_dependency 'rdf-turtle',      '~> 3.3'
  gem.add_development_dependency 'rdf-spec',        '~> 3.3'
  gem.add_development_dependency 'rdf-vocab',       '~> 3.3'
  gem.add_development_dependency 'yard' ,           '~> 0.9'

  gem.post_install_message  = nil
end

