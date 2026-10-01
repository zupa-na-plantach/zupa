require "rails_helper"

RSpec.describe "Admin trip builder", type: :system do
  let(:admin_user) { create(:admin_user, password: "password123", password_confirmation: "password123") }

  before do
    create(:location, name: "Miejsce Alfa", status: "active")
    create(:location, name: "Miejsce Beta", status: "active")
    create(:volunteer, first_name: "Ola", last_name: "Kierowca")
    create(:volunteer, first_name: "Ela", last_name: "Pomocnik")
    admin_login(admin_user)
    Flipper.enable(:trip_builder)
  end

  it "walks the 3-step wizard and creates a manual trip" do
    visit "/admin/trip_builder"
    find("input[type=date]").set("2026-07-01")

    # Step 1 — preselect a location (click its card)
    within("#location-pool") { find("[aria-label='Miejsce Alfa']").click }
    expect(page).to have_content("Wybrane (1)")
    click_button "Dalej", exact: false

    # Step 2 — roster + mark a driver
    click_button "Ola Kierowca"
    click_button "Ela Pomocnik"
    find("[aria-label='Kierowca: Ola Kierowca']").click
    click_button "Dalej", exact: false

    # Step 3 — place into a group (no maps key in test → no map toggle)
    expect(page).not_to have_button("Pokaż mapę")
    within("#location-pool") { click_button "Miejsce Alfa" }
    click_button "Ola Kierowca"
    click_button "Ela Pomocnik"

    # add a per-location note (open the note field on the location card)
    find("[aria-label='Dodatkowe informacje…']").click
    fill_in "Dodatkowe informacje…", with: "Kod do bramy 1234"
    find("input[type=date]").click # blur the note field before submitting

    click_button "Utwórz wyjazd"

    expect(page).to have_current_path(%r{/admin/trips/\d+}, wait: 5)

    trip = Trip.last
    expect(trip).to be_manual
    expect(trip.date).to eq(Date.new(2026, 7, 1))
    group = trip.groups.first
    expect(group.trip_destinations.map { |d| d.location.name }).to eq(["Miejsce Alfa"])
    expect(group.trip_destinations.first.additional_info).to eq("Kod do bramy 1234")
    expect(group.drivers.map(&:full_name)).to eq(["Ola Kierowca"])
    expect(group.volunteers.map(&:full_name)).to eq(["Ela Pomocnik"])
  end

  it "copies the rotation trip's locations AND group layout (Step 1 button)" do
    alfa = Location.find_by(name: "Miejsce Alfa")
    beta = Location.find_by(name: "Miejsce Beta")
    rotation = create(:trip, date: Date.new(2026, 5, 28), organiser: admin_user)
    create(:trip, date: Date.new(2026, 6, 4), organiser: admin_user) # makes rotation the 2nd-most-recent
    g1 = create(:trip_group, trip: rotation, number: 1, volunteer_names: ["x"])
    create(:trip_destination, trip_group: g1, location: alfa, order: 1)
    g2 = create(:trip_group, trip: rotation, number: 2, volunteer_names: ["y"])
    create(:trip_destination, trip_group: g2, location: beta, order: 1)

    visit "/admin/trip_builder"
    find("button", text: "Kopiuj z wyjazdu sprzed 2 tyg.").click
    expect(page).to have_content("Wybrane (2)")

    click_button "Dalej", exact: false
    click_button "Dalej", exact: false
    click_button "Utwórz wyjazd"

    expect(page).to have_current_path(%r{/admin/trips/\d+}, wait: 5)
    created = Trip.find_by(source: "manual")
    layout = created.groups.map { |g| g.trip_destinations.map { |d| d.location.name } }
    expect(layout).to contain_exactly(["Miejsce Alfa"], ["Miejsce Beta"])
  end

  it "hides locations visited on the last trip when toggled (Step 1)" do
    alfa = Location.find_by(name: "Miejsce Alfa")
    trip = create(:trip, organiser: admin_user, date: Date.current)
    g = create(:trip_group, trip: trip, volunteer_names: ["x"])
    create(:trip_destination, trip_group: g, location: alfa, order: 1)

    visit "/admin/trip_builder"

    within("#location-pool") do
      expect(page).to have_css("[aria-label='Miejsce Alfa']")
      check "Ukryj odwiedzone na ostatnim wyjeździe"
      expect(page).not_to have_css("[aria-label='Miejsce Alfa']")
      expect(page).to have_css("[aria-label='Miejsce Beta']")
    end
  end

  it "restores the in-progress wizard from localStorage after a reload" do
    visit "/admin/trip_builder"
    within("#location-pool") { find("[aria-label='Miejsce Alfa']").click }
    expect(page).to have_content("Wybrane (1)")

    visit "/admin/trip_builder" # reload

    expect(page).to have_content("Wybrane (1)")
    within("#location-pool") { expect(page).not_to have_css("[aria-label='Miejsce Alfa']") }
  end

  it "opens an existing manual trip at Step 3 and saves changes" do
    alfa = Location.find_by(name: "Miejsce Alfa")
    trip = Trips::CreateManualTrip.new.call(
      date: Date.current + 7, organiser: admin_user,
      groups: [{location_ids: [alfa.id], driver_ids: [], volunteer_ids: []}]
    ).value!

    visit "/admin/trip_builder?trip_id=#{trip.id}"

    # lands on Step 3 with Alfa already in the group
    expect(page).to have_button("Zapisz zmiany")
    expect(page).to have_content("Miejsce Alfa")

    # back to Step 1 to preselect Beta, then forward and assign it
    click_button "Wstecz", exact: false
    click_button "Wstecz", exact: false
    within("#location-pool") { find("[aria-label='Miejsce Beta']").click }
    click_button "Dalej", exact: false
    click_button "Dalej", exact: false
    within("#location-pool") { click_button "Miejsce Beta" }
    click_button "Zapisz zmiany"

    expect(page).to have_current_path(%r{/admin/trips/#{trip.id}}, wait: 5)
    trip.reload
    expect(trip.groups.flat_map { |g| g.trip_destinations.map { |d| d.location.name } })
      .to contain_exactly("Miejsce Alfa", "Miejsce Beta")
  end
end
