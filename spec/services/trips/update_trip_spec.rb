require "rails_helper"

describe Trips::UpdateTrip do
  it "updates trip recreates the trip groups and destinations with new data" do
    trip = create(:trip,
      date: "2025-05-11",
      source_spreadsheet_url: "https://old.io")

    trip_group = create(:trip_group, trip: trip, volunteer_names: ["*Dyzio", "Zyzio", "Hyzio"])
    create(:trip_destination,
      location: create(:location, name: "Vacant building"),
      trip_group: trip_group)
    tents = create(:location, name: "Tents")
    mall = create(:location, name: "Mall")
    create(:person, location: tents, active: true, soups: 88, sandwiches: 10)
    create(:person, location: mall, active: true, soups: 99, sandwiches: 11)

    build_trip_data = double(:build_trip_data)
    trip_data = instance_double(Trips::TripData,
      groups: [double(:group,
        number: "1",
        volunteers: ["Jerzy*", "Basia", "Gordon"],
        destinations: [
          double(value: "Tents", address: "Tents", additional_info: "", order: 1),
          double(value: "Mall", address: "Mall", additional_info: "", order: 2)
        ])])

    expect(build_trip_data).to receive(:call).and_return(trip_data)

    described_class.new(build_trip_data: build_trip_data).call(
      id: trip.id,
      params: {
        date: "2024-02-29",
        source_spreadsheet_url: "https://new.com",
        active: false
      }
    )

    trip.reload
    expect(trip).not_to be_active
    expect(trip.source_spreadsheet_url).to eq("https://new.com")
    expect(trip.groups.first.number).to eq(1)
    expect(trip.groups.first.volunteer_names).to eq(["Jerzy*", "Basia", "Gordon"])
    destinations = trip.groups.first.trip_destinations.order(:order)
    expect(destinations.map(&:name)).to eq(["Tents", "Mall"])
    expect(destinations.pluck(:soups)).to eq([88, 99])
    expect(destinations.pluck(:sandwiches)).to eq([10, 11])
  end

  it "raises EmptyTripDataError and preserves existing groups when the sheet yields none" do
    trip = create(:trip, date: "2025-05-11", source_spreadsheet_url: "https://old.io")
    create(:trip_group, trip: trip, volunteer_names: ["*Dyzio"])

    builder = instance_double(Trips::BuildTripData, call: instance_double(Trips::TripData, groups: []))

    expect {
      described_class.new(build_trip_data: builder).call(
        id: trip.id,
        params: {date: "2024-02-29", source_spreadsheet_url: "https://new.com", active: false}
      )
    }.to raise_error(Trips::EmptyTripDataError)

    expect(trip.reload.groups.count).to eq(1)
  end
end
