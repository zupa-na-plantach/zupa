require "rails_helper"

RSpec.describe "AdminArea::TripBuilder", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:location) { create(:location, name: "Miejsce A", status: "active") }
  let(:driver) { create(:volunteer) }
  let(:helper) { create(:volunteer) }

  def stub_current_user
    allow_any_instance_of(AdminArea::ApplicationController).to receive(:authorize!) do |ctrl|
      ctrl.instance_variable_set(:@current_user, admin_user)
      true
    end
  end

  before do
    stub_current_user
    Flipper.enable(:trip_builder)
  end

  describe "feature flag gating" do
    it "rejects the request when :trip_builder is off for the user" do
      Flipper.disable(:trip_builder)
      post "/admin_area/trip_builder", params: {date: "2026-07-01", groups: []}, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /admin_area/trip_builder" do
    it "creates a manual trip and returns a redirect target" do
      payload = {
        date: "2026-07-01",
        admin_user_id: admin_user.id,
        groups: [
          {location_ids: [location.id], driver_ids: [driver.id], volunteer_ids: [helper.id]}
        ]
      }

      expect {
        post "/admin_area/trip_builder", params: payload, as: :json
      }.to change(Trip, :count).by(1)

      expect(response).to have_http_status(:created)
      trip = Trip.last
      expect(trip).to be_manual
      expect(trip.organiser).to eq(admin_user)
      expect(JSON.parse(response.body)["redirect_to"]).to eq("/admin/trips/#{trip.id}")

      group = trip.groups.first
      expect(group.drivers).to contain_exactly(driver)
      expect(group.volunteers).to contain_exactly(helper)
      expect(group.trip_destinations.first.location).to eq(location)
    end

    it "returns 422 with errors when the payload is invalid" do
      payload = {date: "", admin_user_id: admin_user.id, groups: []}

      expect {
        post "/admin_area/trip_builder", params: payload, as: :json
      }.not_to change(Trip, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end
  end

  describe "PATCH /admin_area/trip_builder/:id" do
    let(:other_location) { create(:location, name: "Miejsce B", status: "active") }
    let(:new_date) { Date.current + 14 }

    def manual_trip
      Trips::CreateManualTrip.new.call(
        date: Date.current + 7, organiser: admin_user,
        groups: [{location_ids: [location.id], driver_ids: [], volunteer_ids: []}]
      ).value!
    end

    it "replaces the trip and returns a redirect target" do
      trip = manual_trip

      patch "/admin_area/trip_builder/#{trip.id}",
        params: {
          date: new_date.iso8601,
          admin_user_id: admin_user.id,
          groups: [{location_ids: [other_location.id], driver_ids: [driver.id], volunteer_ids: [helper.id]}]
        },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["redirect_to"]).to eq("/admin/trips/#{trip.id}")
      trip.reload
      expect(trip.date).to eq(new_date)
      expect(trip.groups.first.trip_destinations.map { |d| d.location }).to eq([other_location])
    end

    it "returns 422 for a past trip" do
      trip = manual_trip
      trip.update_column(:date, Date.yesterday)

      patch "/admin_area/trip_builder/#{trip.id}",
        params: {date: new_date.iso8601, admin_user_id: admin_user.id, groups: [{location_ids: [other_location.id]}]},
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
