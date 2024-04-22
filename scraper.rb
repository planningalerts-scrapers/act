require "mechanize"
require "scraperwiki"
require "json"

# Convert timestamp (in milliseconds) to iso whatever thingy date string
def convert_date(timestamp)
  Time.at(timestamp / 1000).to_date.to_s
end

def get_page(url, base_info_url, query, count, offset)
  # mechanize is maintaining some state that is causing the API to return a cached version of the last
  # request I think. So, work around this by not passing any state and setting up a new ruby mechanize agent
  # for every request
  page = Mechanize.new.post(
    url,
    query.merge(
      "resultRecordCount" => count,
      "resultOffset"      => offset
    )
  )
  result = JSON.parse(page.body)

  result["features"].map{|r| r["attributes"]}.map do |a|
    council_reference = a["DA_NUMBER"]

    {
      council_reference: council_reference,
      address: a["STREET_ADDRESS"] + ", " + a["SUBURB"] + ", ACT",
      description: a["PROPOSAL_TEXT"],
      info_url: "#{base_info_url}?da-number=#{council_reference}",
      date_scraped: Date.today.to_s,
      date_received: convert_date(a["LODGEMENT_DATE"]),
      on_notice_from: convert_date(a["DATE_START"]),
      on_notice_to: convert_date(a["DATE_END"]),
      lat: a["CENTROID_LAT"],
      lng: a["CENTROID_LONG"],
    }  
  end
end

def get_total_count(url, query)
  page = Mechanize.new.post(
    url,
    query.merge(
      # I think this value is arbitrary here
      "resultRecordCount" => 5,
      "resultOffset"      => 0,
      "returnCountOnly"   => "true"  
    )
  )
  result = JSON.parse(page.body)
  result["count"]
end

base_info_url = "https://www.planning.act.gov.au/applications-and-assessments/development-applications/browse-das/development-application-details"
url = "https://services1.arcgis.com/E5n4f1VY84i0xSjy/arcgis/rest/services/ACTGOV_DAFINDER_LIST_VIEW/FeatureServer/0/query"

# This includes things except for paging specific stuff and controlling counts
query = {
  "f"              => "json",
  "returnGeometry" => "false",
  "outFields"      => "*",
  "where"          => "OBJECTID IS NOT NULL AND (DA_STAGE = 'On notification')",
  "orderByFields"  => "SUBURB ASC"
}

count = get_total_count(url, query)
puts "Count: #{count}"

get_page(url, base_info_url, query, 5, 0).each do |record|
  pp record

  ScraperWiki.save_sqlite([:council_reference], record)
end

