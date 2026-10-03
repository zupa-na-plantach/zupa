# Permanently redirects requests for old hostnames (e.g. the domain the app
# used before moving to Render) to the current one, keeping path and query.
class LegacyHostRedirect
  def initialize(app, hosts:, target:)
    @app = app
    @hosts = hosts.map { |host| host.strip.downcase }.reject(&:empty?)
    @target = target.to_s.chomp("/")
  end

  def call(env)
    request = Rack::Request.new(env)
    return @app.call(env) if @target.empty? || !@hosts.include?(request.host.downcase)

    [301, {"Location" => "#{@target}#{request.fullpath}", "Content-Type" => "text/plain"}, ["Moved to #{@target}"]]
  end
end
