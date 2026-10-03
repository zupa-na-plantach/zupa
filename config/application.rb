require_relative "boot"

require "rails/all"
require_relative "../lib/legacy_host_redirect"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Zupa
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Europe/Warsaw"
    # config.eager_load_paths << Rails.root.join("extras")

    config.api_only = false
    config.generators do |g|
      g.test_framework :rspec,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        controller_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.integration_tool :rspec
    end

    config.i18n.default_locale = :pl

    # Old domains (comma-separated REDIRECT_HOSTS) get a 301 to HOST.
    config.middleware.insert_before 0, LegacyHostRedirect,
      hosts: ENV.fetch("REDIRECT_HOSTS", "").split(","),
      target: ENV["HOST"]
  end
end
