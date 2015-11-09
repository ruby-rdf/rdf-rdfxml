source "https://rubygems.org"

gemspec

gem "nokogiri"

group :development do
  gem "equivalent-xml"
end

group :debug do
  gem "wirble"
  gem "byebug", :platforms => :mri_21
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
