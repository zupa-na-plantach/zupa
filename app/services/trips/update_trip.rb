module Trips
  class UpdateTrip
    def initialize(build_trip_data: BuildTripData.new)
      @build_trip_data = build_trip_data
    end

    def call(id:, params:)
      trip = Trip.includes(groups: :trip_destinations).find(id)
      date = params.fetch(:date)
      spreadsheet_url = params.fetch(:source_spreadsheet_url)

      trip_data = build_trip_data.call(date: date, spreadsheet_url: spreadsheet_url)

      raise EmptyTripDataError if trip_data.groups.empty?

      validation = validate_destinations(trip_data)

      if validation == true
        ActiveRecord::Base.transaction do
          update_groups(trip_data.groups, trip)
          trip.update!(params)
        end
      end

      validation
    end

    private

    attr_reader :build_trip_data

    def update_groups(groups_data, trip)
      trip.groups.destroy_all
      TripRepository.new.create_groups(groups_data, trip)
    end

    def validate_destinations(trip_data)
      destinations = trip_data.groups.flat_map { |group| group.destinations }

      ValidateTripDestinations.new.call(trip_destinations: destinations)
    end
  end
end
