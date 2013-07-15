source "https://rubygems.org"

gemspec

gem "rdf",            :git => "git://github.com/ruby-rdf/rdf.git", :branch => "1.1"
gem "rdf-xsd",        :git => "git://github.com/ruby-rdf/rdf-xsd.git", :branch => "1.1"

group :development do
  gem "rdf-spec",       :git => "git://github.com/ruby-rdf/rdf-spec.git", :branch => "1.1"
  gem "rdf-turtle",     :git => "git://github.com/ruby-rdf/rdf-turtle.git", :branch => "1.1"
end

group :debug do
  gem "wirble"
  gem "debugger", :platforms => [:mri_19]
end
