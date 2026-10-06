require "rails_helper"

describe Trips::ParseGoogleSpreadsheet do
  it "returns spreadsheet object", vcr: {match_requests_on: [:method, :uri]} do
    spreadsheet = described_class.new.call(spreadsheet_url: "https://docs.google.com/spreadsheets/d/10HruPjeSsZX2-IYSkpTxPd-Jfnc9jTDRXcTFHWymlZw/edit#gid=0")

    expect(spreadsheet.rows.count).to eq(18)
    expect(spreadsheet.rows[0].first).to eq("GRUPA / MIEJSCA")
    expect(spreadsheet.rows[1].first).to eq("GR 1: Jan Kowalski*, Polimeria Gnat, Wyszeniega Zanussi")
    expect(spreadsheet.rows[2].first).to eq("Location 13 - parking (to verify)")
    expect(spreadsheet.rows[7].first).to eq("GR 2: Elżbieta Łinsdor*, Miłorad Jackiewicz, Trzebiesława Drewniakowska")
    expect(spreadsheet.rows[13].first).to eq("GR 3: Alan Wake*, Książe Persii, Bezimienny")
  end

  it "reads the first worksheet that has data, skipping empty leading tabs" do
    empty_tab = double(num_rows: 0, rows: [])
    data_tab = double(num_rows: 2, rows: [["GR 1: Anna"], ["Location 1 - x"]])
    spreadsheet = double(worksheets: [empty_tab, data_tab])
    session = double(spreadsheet_by_key: spreadsheet)
    allow(GoogleDrive::Session).to receive(:from_service_account_key).and_return(session)

    result = described_class.new.call(spreadsheet_url: "https://docs.google.com/spreadsheets/d/abc/edit")

    expect(result.rows).to eq([["GR 1: Anna"], ["Location 1 - x"]])
  end

  it "raises a friendly error when the sheet is not accessible" do
    allow(GoogleDrive::Session).to receive(:from_service_account_key)
      .and_raise(Google::Apis::ClientError.new("forbidden"))

    expect {
      described_class.new.call(spreadsheet_url: "https://docs.google.com/spreadsheets/d/abc/edit")
    }.to raise_error(Trips::SpreadsheetAccessError, /udostępniony/)
  end
end
