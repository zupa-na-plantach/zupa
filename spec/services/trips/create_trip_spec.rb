require "rails_helper"

describe Trips::CreateTrip do
  let(:admin) { create(:admin_user) }
  let(:spreadsheet_url) { "https://docs.google.com/spreadsheets/d/10HruPjeSsZX2-IYSkpTxPd-Jfnc9jTDRXcTFHWymlZw/edit#gid=0" }

  before do
    # location names must match location names in the spreadsheet
    create(:location, name: "Location 13 - parking (to verify)")
    create(:location, name: "Location 7 - trailer")
    create(:location, name: "Location 4 - garage")
    create(:location, name: "Location 10 - tunnel")
    create(:location, name: "Location 14 - clinic")
    create(:location, name: "Location 9 - new location")
    location_1 = create(:location, name: "Location 1")
    create(:location, name: "Location 12 - vacant developer space")
    create(:location, name: "Location 2")

    # Counts now come from DB Person records, not from the spreadsheet.
    create(:person, location: location_1, active: true,
      sandwiches: 10, soups: 5, sparkling_water: 2, still_water: 1,
      long_term_provisions: true, book_preferences: "Kryminały")
    create(:person, location: location_1, active: true,
      sandwiches: 6, soups: 3, sparkling_water: 0, still_water: 0,
      long_term_provisions: false, book_preferences: nil)
  end

  describe "create new trip from Google spreadsheet" do
    it "with proper date, organiser and groups", vcr: {match_requests_on: [:method, :uri]} do
      described_class.new.call(
        {
          date: "2024-02-08",
          source_spreadsheet_url: spreadsheet_url,
          admin_user_id: admin.id,
          active: true
        }
      )

      trip = Trip.first
      expect(trip).to be_active
      expect(trip.date.to_s).to eq("2024-02-08")
      expect(trip.organiser).to eq(admin)
      expect(trip.groups.count).to eq(3)
      expect(trip.groups.first.volunteer_names).to eq(["Jan Kowalski*", "Polimeria Gnat", "Wyszeniega Zanussi"])
      expect(trip.groups.second.volunteer_names).to eq(["Elżbieta Łinsdor*", "Miłorad Jackiewicz", "Trzebiesława Drewniakowska"])
      expect(trip.groups.last.volunteer_names).to eq(["Alan Wake*", "Książe Persii", "Bezimienny"])
    end

    it "with proper details from columns", vcr: {match_requests_on: [:method, :uri]} do
      described_class.new.call(
        {
          date: "2024-02-08",
          source_spreadsheet_url: spreadsheet_url,
          admin_user_id: admin.id,
          active: true
        }
      )

      trip = Trip.first
      group = trip.groups.find_by(number: 3)
      expect(group.trip_destinations.count).to eq 3
      expect(group.trip_destinations.pluck(:order)).to match [1, 2, 3]

      first_destination = group.trip_destinations.find_by(order: 1)
      expect(first_destination.name).to eq "Location 1"
      expect(first_destination.sandwiches).to eq 16
      expect(first_destination.soups).to eq 8
      expect(first_destination.provisions).to eq 1
      expect(first_destination.books).to eq 1
      expect(first_destination.waters).to eq 3
      expect(first_destination.chocolates).to eq first_destination.trip_destination_people.sum(:chocolates)
      expect(first_destination.person_count).to eq 2
      expect(first_destination.trip_destination_people.count).to eq 2
      expect(first_destination.additional_info).to eq "Lorem ipsum dolor sit amet, consectetur adipiscing elit"
      expect(first_destination.location_snapshot["name"]).to eq("Location 1")
    end
  end

  describe "when the parsed sheet yields no groups" do
    it "raises EmptyTripDataError and creates no trip" do
      builder = instance_double(Trips::BuildTripData, call: double(groups: []))

      expect {
        described_class.new(build_trip_data: builder).call(
          {
            date: "2024-02-08",
            source_spreadsheet_url: spreadsheet_url,
            admin_user_id: admin.id,
            active: true
          }
        )
      }.to raise_error(Trips::EmptyTripDataError)

      expect(Trip.count).to eq(0)
    end
  end
end
