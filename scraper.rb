require 'mechanize'
require 'scraperwiki'

agent = Mechanize.new
url = "https://www.planning.act.gov.au/development-applications-assessments/development-applications"
page = agent.get(url)

page.search(".DA-list-item").each do |item|
  suburb = item.at(".suburb").inner_text.strip
  street_address = item.at(".street-address").inner_text.strip
  address = "#{street_address}, #{suburb}, ACT"
  record = {
    council_reference: item.at(".da-number h2").inner_text.strip,
    address: address,
    description: item.at(".proposal-text").inner_text.strip,
    on_notice_to: Date.parse(item.at(".representation-closes strong"), "d/m/Y").to_s,
    info_url: item.at(".da-links a.da-links__details")["href"],
    date_scraped: Date.today.to_s
  }
  if street_address == ""
    puts "Skipping #{record[:council_reference]} because it has an empty street address"
    next
  end

  ScraperWiki.save_sqlite([:council_reference], record)
end
