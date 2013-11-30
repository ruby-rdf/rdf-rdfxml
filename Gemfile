source "https://rubygems.org"

gemspec

gem "rdf",            :git => "git://github.com/ruby-rdf/rdf.git", :branch => "develop"
gem "rdf-rdfa",        :git => "git://github.com/ruby-rdf/rdf-rdfa.git", :branch => "develop"
gem "rdf-xsd",        :git => "git://github.com/ruby-rdf/rdf-xsd.git", :branch => "develop"

group :development do
  gem 'json-ld',        :git => "git://github.com/ruby-rdf/json-ld.git", :branch => "develop"
  gem 'rdf-isomorphic', :git => "git://github.com/ruby-rdf/rdf-isomorphic.git", :branch => "develop"
  gem "rdf-spec",       :git => "git://github.com/ruby-rdf/rdf-spec.git", :branch => "develop"
  gem "rdf-turtle",     :git => "git://github.com/ruby-rdf/rdf-turtle.git", :branch => "develop"
end

group :debug do
  gem "wirble"
  gem "ruby-debug", :platforms => :jruby
  gem "debugger", :platforms => :mri_19
  gem "byebug", :platforms => :mri_20
end
