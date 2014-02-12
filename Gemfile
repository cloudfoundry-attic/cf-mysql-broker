source 'https://rubygems.org'

gem 'rails'
gem 'rails-api'
gem 'settingslogic'
gem 'mysql2'
gem 'cf-uaa-lib', '~>1.3.0' # this is a dependency of the omniauth-uaa-oauth2, which doesn't work with 2.0 versions
gem 'omniauth-uaa-oauth2', github: 'cloudfoundry/omniauth-uaa-oauth2', branch: 'error_handling'

group :production do
  gem 'unicorn'
end

group :development, :test do
  gem 'rspec-rails'
end

group :test do
  gem 'webmock'
end
