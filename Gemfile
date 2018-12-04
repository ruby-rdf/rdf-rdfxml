source "https://rubygems.org"

gemspec

gem "rdf", '~> 1.99'
gem "rdf-rdfa", git: 'git://github.com/ruby-rdf/rdf-rdfa.git', branch: "1.99-support"
gem "nokogiri"

group :debug do
  gem "wirble"
  gem "ruby-debug", :platforms => :jruby
  gem "debugger", :platforms => :mri_19
  gem "byebug", :platforms => [:mri_20, :mri_21]
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
