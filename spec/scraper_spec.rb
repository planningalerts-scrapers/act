# frozen_string_literal: true

RSpec.describe ActScraper do
  describe ".convert_date" do
    it "converts a millisecond timestamp to an ISO 8601 date string" do
      expect(described_class.convert_date(1_784_592_000_000)).to eq "2026-07-21"
    end
  end

  describe ".record_from_attributes" do
    let(:attributes) do
      {
        "DA_NUMBER" => "202645429",
        "STREET_ADDRESS" => "UNIT 17, 2 YULE STREET",
        "SUBURB" => "AMAROO",
        "PROPOSAL_TEXT" => "PLANNING ACT 2023 - PROPOSAL FOR DWELLING ALTERATIONS",
        "LODGEMENT_DATE" => 1_784_592_000_000,
        "DATE_START" => 1_785_110_400_000,
        "DATE_END" => 1_786_665_600_000,
        "CENTROID_LAT" => -35.166095595049086,
        "CENTROID_LONG" => 149.12661253833474
      }
    end

    it "maps API attributes to a planning application record" do
      Timecop.freeze(Date.new(2026, 8, 11)) do
        expect(described_class.record_from_attributes(attributes)).to eq(
          council_reference: "202645429",
          address: "UNIT 17, 2 YULE STREET, AMAROO, ACT",
          description: "PLANNING ACT 2023 - PROPOSAL FOR DWELLING ALTERATIONS",
          info_url: "https://www.planning.act.gov.au/applications-and-assessments/" \
                    "development-applications/browse-das/development-application-details" \
                    "?da-number=202645429",
          date_scraped: "2026-08-11",
          date_received: "2026-07-21",
          on_notice_from: "2026-07-27",
          on_notice_to: "2026-08-14",
          lat: -35.166095595049086,
          lng: 149.12661253833474
        )
      end
    end

    it "skips records without a street address" do
      expect(described_class.record_from_attributes(attributes.merge("STREET_ADDRESS" => nil))).to be_nil
    end
  end

  describe ".scrape", :vcr do
    it "collects development applications with the expected fields" do
      records = []
      described_class.scrape { |record| records << record }

      expect(records).not_to be_empty
      expect(records.map { |r| r[:council_reference] }.uniq.length).to eq records.length

      records.each do |record|
        expect(record[:council_reference]).to match(/\A\d+\z/)
        expect(record[:address]).to end_with(", ACT")
        expect(record[:description]).not_to be_nil
        expect(record[:info_url]).to start_with("https://www.planning.act.gov.au/")
        expect(record[:info_url]).to include(record[:council_reference])
        expect(Date.parse(record[:date_scraped])).to be_a(Date)
        expect(Date.parse(record[:date_received])).to be <= Date.today
        expect(Date.parse(record[:on_notice_from])).to be <= Date.parse(record[:on_notice_to])
        expect(record[:lat]).to be_between(-36, -35)
        expect(record[:lng]).to be_between(148, 150)
      end
    end
  end

  describe ".run", :vcr do
    it "saves each scraped record with ScraperWiki" do
      saved = []
      allow(ScraperWiki).to receive(:save_sqlite) { |keys, record| saved << [keys, record] }

      expect { described_class.run }.to output(/Saving .+\.\.\./).to_stdout

      expect(saved).not_to be_empty
      saved.each do |keys, record|
        expect(keys).to eq [:council_reference]
        expect(record[:council_reference]).to match(/\A\d+\z/)
      end
    end
  end
end
