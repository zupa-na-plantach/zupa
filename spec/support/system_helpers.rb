# frozen_string_literal: true

module SystemHelpers
  def admin_login(admin_user)
    visit "/admin/login"
    fill_in "Email", with: admin_user.email
    fill_in "Hasło", with: admin_user.password
    click_button "Zaloguj się"
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system

  config.before(type: :system) do
    driven_by :cuprite, screen_size: [1280, 800], options: {
      headless: ENV.fetch("HEADLESS", "true") != "false",
      inspector: ENV.key?("INSPECTOR"),
      slowmo: ENV["SLOWMO"]&.to_f,
      # Chrome can take >10s to start on a cold CI runner; the first system
      # spec then failed with Ferrum::ProcessTimeoutError.
      process_timeout: 30
    }
  end

  config.after(type: :system) do |example|
    if example.exception
      filename = example.full_description.parameterize(separator: "_")
      path = Rails.root.join("tmp", "screenshots", "#{filename}.png")
      FileUtils.mkdir_p(File.dirname(path))
      page.save_screenshot(path)
    end
  end
end
