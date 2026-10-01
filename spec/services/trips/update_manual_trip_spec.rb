require "rails_helper"

RSpec.describe Trips::UpdateManualTrip do
  let(:admin) { create(:admin_user) }
  let(:other_admin) { create(:admin_user) }
  let(:loc_a) { create(:location, name: "A") }
  let(:loc_b) { create(:location, name: "B") }
  let!(:person_b) { create(:person, location: loc_b, active: true, sandwiches: 3) }
  let(:driver) { create(:volunteer) }
  let(:helper) { create(:volunteer) }
  let(:trip_date) { Date.current + 7 }
  let(:new_date) { Date.current + 14 }

  def create_trip
    Trips::CreateManualTrip.new.call(
      date: trip_date,
      organiser: admin,
      groups: [{location_ids: [loc_a.id], driver_ids: [], volunteer_ids: []}]
    ).value!
  end

  it "replaces groups, updates basics, and re-freezes snapshots" do
    trip = create_trip

    result = described_class.new.call(
      trip: trip,
      date: new_date,
      organiser: other_admin,
      groups: [{location_ids: [loc_b.id], driver_ids: [driver.id], volunteer_ids: [helper.id]}]
    )

    expect(result).to be_success
    trip.reload
    expect(trip.date).to eq(new_date)
    expect(trip.organiser).to eq(other_admin)
    expect(trip.groups.count).to eq(1)

    group = trip.groups.first
    expect(group.trip_destinations.map { |d| d.location.name }).to eq(["B"])
    expect(group.trip_destinations.first.trip_destination_people.count).to eq(1) # snapshot refreshed
    expect(group.drivers).to contain_exactly(driver)
    expect(group.volunteers).to contain_exactly(helper)
  end

  it "replaces the access code on update" do
    trip = create_trip
    Trips::UpdateManualTrip.new.call(
      trip: trip, date: new_date, organiser: admin,
      groups: [{location_ids: [loc_a.id]}], access_code: "newcode1"
    )
    expect(trip.reload.auth_code.value).to eq("newcode1")
    expect(AuthCode.where(trip: trip).count).to eq(1)

    Trips::UpdateManualTrip.new.call(
      trip: trip, date: new_date, organiser: admin,
      groups: [{location_ids: [loc_a.id]}], access_code: ""
    )
    expect(trip.reload.auth_code).to be_nil
  end

  it "rejects a past trip" do
    trip = create_trip
    trip.update_column(:date, Date.yesterday)

    result = described_class.new.call(
      trip: trip, date: Date.tomorrow, organiser: admin,
      groups: [{location_ids: [loc_b.id]}]
    )
    expect(result).to be_failure
  end

  it "converts a sheet trip to a manual trip" do
    sheet_trip = create(:trip, organiser: admin, date: trip_date, source: "sheet")

    result = described_class.new.call(
      trip: sheet_trip, date: new_date, organiser: admin,
      groups: [{location_ids: [loc_b.id]}]
    )

    expect(result).to be_success
    expect(sheet_trip.reload.source).to eq("manual")
    expect(sheet_trip.groups.first.trip_destinations.map(&:location)).to eq([loc_b])
  end
end
