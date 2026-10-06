module Trips
  class EmptyTripDataError < StandardError
    MESSAGE =
      "Arkusz nie zawiera żadnych grup wyjazdowych (np. „GR 1: ...”). " \
      "Sprawdź, czy dane są w pierwszej zakładce arkusza i czy nagłówki grup są poprawne."

    def initialize(message = MESSAGE)
      super
    end
  end

  class CreateTrip
    def initialize(build_trip_data: BuildTripData.new)
      @build_trip_data = build_trip_data
    end

    def call(params)
      date = params.fetch(:date)
      spreadsheet_url = params.fetch(:source_spreadsheet_url)

      trip_data = build_trip_data.call(date: date, spreadsheet_url: spreadsheet_url)

      raise EmptyTripDataError if trip_data.groups.empty?

      validation = validate_destinations(trip_data)

      if validation == true
        create_in_db!(trip_data, params)
      end

      validation
    end

    private

    attr_reader :build_trip_data

    def create_in_db!(trip_data, params)
      TripRepository.new.create!(trip_data: trip_data, params: params)
    end

    def validate_destinations(trip_data)
      destinations = trip_data.groups.flat_map { |group| group.destinations }

      ValidateTripDestinations.new.call(trip_destinations: destinations)
    end
  end
end
