require "rails_helper"

RSpec.describe LegacyHostRedirect do
  let(:inner_app) { ->(_env) { [200, {"Content-Type" => "text/plain"}, ["app"]] } }
  let(:middleware) do
    described_class.new(inner_app, hosts: ["zupa.lunarlogic.io", "www.zupa.lunarlogic.io"], target: "https://zupa.onrender.com")
  end

  def get(url)
    middleware.call(Rack::MockRequest.env_for(url))
  end

  it "permanently redirects a legacy host to the target, keeping path and query" do
    status, headers, _body = get("https://zupa.lunarlogic.io/admin/trips?page=2")

    expect(status).to eq(301)
    expect(headers["Location"]).to eq("https://zupa.onrender.com/admin/trips?page=2")
  end

  it "redirects the www variant" do
    status, headers, _body = get("http://www.zupa.lunarlogic.io/")

    expect(status).to eq(301)
    expect(headers["Location"]).to eq("https://zupa.onrender.com/")
  end

  it "passes other hosts through to the app" do
    status, _headers, body = get("https://zupa.onrender.com/admin")

    expect(status).to eq(200)
    expect(body).to eq(["app"])
  end

  it "passes everything through when no legacy hosts are configured" do
    passthrough = described_class.new(inner_app, hosts: [], target: "https://zupa.onrender.com")

    status, _headers, _body = passthrough.call(Rack::MockRequest.env_for("https://zupa.lunarlogic.io/"))

    expect(status).to eq(200)
  end

  it "passes everything through when the target is blank" do
    passthrough = described_class.new(inner_app, hosts: ["zupa.lunarlogic.io"], target: "")

    status, _headers, _body = passthrough.call(Rack::MockRequest.env_for("https://zupa.lunarlogic.io/"))

    expect(status).to eq(200)
  end
end
