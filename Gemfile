source "https://rubygems.org"

gemspec

gem "rdf",            :git => "git://github.com/ruby-rdf/rdf.git", :branch => "develop"
gem "rdf-xsd",        :git => "git://github.com/ruby-rdf/rdf-xsd.git", :branch => "develop"

group :development do
  gem "rdf-spec",       :git => "git://github.com/ruby-rdf/rdf-spec.git", :branch => "develop"
  gem "rdf-turtle",     :git => "git://github.com/ruby-rdf/rdf-turtle.git", :branch => "develop"
end

group :debug do
  gem "wirble"
  gem "debugger", :platforms => [:mri_19]
end
