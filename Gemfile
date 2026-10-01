source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.7"

gem "rails", "~> 7.0.4"
gem "sprockets-rails"
gem "puma", "~> 5.0"
gem "jsbundling-rails"
gem "cssbundling-rails", "~> 1.1"
gem "jbuilder", "~> 2.11.5"
gem "pg", "~> 1.1"
gem "rswag-api", "~> 2.8.0"
gem "rswag-ui", "~> 2.8.0"
gem "dry-monads", "~> 1.3"
gem "mustache", "~> 1.1"

gem "stimulus-rails", "~> 1.3"
gem "turbo-rails"

# Use Redis for Action Cable
gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem

# There is an issue with the platforms for tzinfo gem & ruby 3.1, so I removed it to be able to work on it - https://github.com/tzinfo/tzinfo/issues/128
gem "tzinfo-data"
gem "bootsnap", require: false
gem "sassc-rails"
gem "trestle"
gem "trestle-auth"
gem "trestle-search"
gem "sass"
gem "jwt"
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"
gem "google_drive"
gem "nio4r", ">= 2.5.9", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

gem "aws-sdk-s3", "~> 1", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "bcrypt_pbkdf"
  gem "dotenv-rails", "~> 2.8.1"
  gem "ed25519"
  gem "rspec-rails", "~> 6.0.1"
  gem "factory_bot_rails", "~> 6.2.0"
  gem "rswag-specs", "~> 2.8.0"
  gem "standardrb"
  gem "vcr"
  gem "webmock"
  gem "capybara", "~> 3.40"
  gem "cuprite", "~> 0.15"
end

group :development do
  gem "web-console"
  gem "spring"
  gem "spring-commands-rspec", "~> 1.0"
end

gem "pagy", "~> 9.0"
