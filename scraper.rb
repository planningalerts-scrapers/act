#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
Bundler.require

require "date"
require "json"

# Scrapes development applications currently on notification from the ACT
# government's public ArcGIS "DA Finder" API and saves them with ScraperWiki.
module ActScraper
  INFO_URL_BASE = "https://www.planning.act.gov.au/applications-and-assessments/" \
                  "development-applications/browse-das/development-application-details"
  API_URL = "https://services1.arcgis.com/E5n4f1VY84i0xSjy/arcgis/rest/services/" \
            "ACTGOV_DAFINDER_LIST_VIEW/FeatureServer/0/query"
  # Use the maximum page size used by the web interface
  PAGE_SIZE = 50

  # Everything except the paging-specific parameters
  BASE_QUERY = {
    "f" => "json",
    "returnGeometry" => "false",
    "outFields" => "*",
    "where" => "OBJECTID IS NOT NULL AND (DA_STAGE = 'On notification')",
    "orderByFields" => "SUBURB ASC"
  }.freeze

  # Convert a timestamp in milliseconds to an ISO 8601 date string
  def self.convert_date(timestamp)
    Time.at(timestamp / 1000).to_date.to_s
  end

  def self.fetch_json(params)
    # Mechanize maintains some state that causes the API to return a cached
    # version of the previous request, so use a fresh agent for every request
    page = Mechanize.new.post(API_URL, BASE_QUERY.merge(params))
    JSON.parse(page.body)
  end

  def self.total_count
    result = fetch_json(
      # This value appears to be arbitrary when only asking for the count
      "resultRecordCount" => 5,
      "resultOffset" => 0,
      "returnCountOnly" => "true"
    )
    result["count"]
  end

  def self.records_for_page(offset)
    result = fetch_json("resultRecordCount" => PAGE_SIZE, "resultOffset" => offset)
    result["features"].filter_map { |feature| record_from_attributes(feature["attributes"]) }
  end

  def self.record_from_attributes(attributes)
    council_reference = attributes["DA_NUMBER"]
    street_address = attributes["STREET_ADDRESS"]
    # Skip if the address is empty
    return if street_address.nil?

    {
      council_reference: council_reference,
      address: "#{street_address}, #{attributes['SUBURB']}, ACT",
      description: attributes["PROPOSAL_TEXT"],
      info_url: "#{INFO_URL_BASE}?da-number=#{council_reference}",
      date_scraped: Date.today.to_s,
      date_received: convert_date(attributes["LODGEMENT_DATE"]),
      on_notice_from: convert_date(attributes["DATE_START"]),
      on_notice_to: convert_date(attributes["DATE_END"]),
      lat: attributes["CENTROID_LAT"],
      lng: attributes["CENTROID_LONG"]
    }
  end

  def self.scrape(&)
    offset = 0
    count = total_count
    while offset < count
      records_for_page(offset).each(&)
      offset += PAGE_SIZE
    end
  end

  def self.run
    count = 0
    scrape do |record|
      puts "Saving #{record[:address]}..."
      ScraperWiki.save_sqlite([:council_reference], record)
      count += 1
    end
    puts "Finished - added #{count} records."
  end
end

ActScraper.run if $PROGRAM_NAME == __FILE__
