source "https://rubygems.org"

gemspec

gem 'rdf',            github: "ruby-rdf/rdf",       branch: "develop"
gem 'rdf-rdfa',       github: "ruby-rdf/rdf-rdfa",  branch: "develop"
gem "nokogiri",       '~> 1.10', platforms: [:mri, :jruby]

group :development do
  gem 'ebnf',               github: "dryruby/ebnf",                 branch: "develop"
  gem 'json-ld',            github: "ruby-rdf/json-ld",             branch: "develop"
  gem 'rdf-aggregate-repo', github: "ruby-rdf/rdf-aggregate-repo",  branch: "develop"
  gem 'rdf-isomorphic',     github: "ruby-rdf/rdf-isomorphic",      branch: "develop"
  gem 'rdf-spec',           github: "ruby-rdf/rdf-spec",            branch: "develop"
  gem 'rdf-turtle',         github: "ruby-rdf/rdf-turtle",          branch: "develop"
  gem 'rdf-vocab',          github: "ruby-rdf/rdf-vocab",           branch: "develop"
  gem "rdf-xsd",            github: "ruby-rdf/rdf-xsd",             branch: "develop"
  gem 'sxp',                github: "dryruby/sxp.rb",               branch: "develop"

  gem "equivalent-xml"
end

group :debug do
  gem "byebug",     platform: :mri
end

group :test do
  gem 'simplecov',      '~> 0.16', platforms: :mri
  gem 'coveralls',      '~> 0.8', platforms: :mri
end
