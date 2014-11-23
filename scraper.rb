require 'mechanize'
require 'scraperwiki'
require 'date'
require 'rubygems'
require 'json'
require 'net/http'
require 'open-uri'

agent = Mechanize.new
url = "http://www.actpla.act.gov.au/topics/your_say/comment/pubnote"
page = agent.get(url)

# Walking through the lines. Every 7 lines is a new application
applications = []
application = {date_scraped: Date.today}
current_suburb = ''
page.search('.listing > *').each do |line|
  if line.text.strip! == "Click here to view the plans"
    application[:info_url] = line.children.first["href"]
        # try to reverse geocode applications with no address
	if application[:address].nil? or application[:address].include?('NO ADDRESS')
		suburb = application[:suburb].gsub(/\\/, '\&\&').gsub(/'/, "''")
		urlsuburb = CGI::escape(suburb)
		result = ScraperWiki.select("* from swdata where `suburb`='#{suburb}' and `block`='#{application[:block]}' and `section`='#{application[:section]}'")	
		if (result.empty? rescue true)
		    puts "geocoding for suburb=#{urlsuburb} block=#{application[:block]} section=#{application[:section]} address=#{application[:address]}"
		    url = "http://www.actmapi.act.gov.au/actmapi/rest/services/mga/basic/MapServer/75/query?where=SECTION_NUMBER%3D#{application[:section]}+and+BLOCK_NUMBER%3D#{application[:block]}+and+DIVISION_NAME%3D%27#{urlsuburb}%27&outFields=ADDRESSES&returnGeometry=true&outSR=4326&f=pjson"
		    resp = Net::HTTP.get_response(URI.parse(url))
  		    data = resp.body
 		    result = JSON.parse(data)
		    if not result['features'].empty? and not result['features'].first['ADDRESSES'].nil?
			puts result['features'].first['ADDRESSES'].first
		        application[:address] = result['features'].first['ADDRESSES'].first
		    end
		    if not result['features'].empty? and not result['features'].first["geometry"].nil?
			geom = result['features'].first["geometry"]
			# just take first point, finding the center is harder and further away from roads http://stackoverflow.com/a/18623672
			lng = geom["rings"].first.first[0]
			lat = geom["rings"].first.first[1]
			gurl = "http://maps.googleapis.com/maps/api/geocode/json?latlng=#{lat},#{lng}&key="
	                gresp = Net::HTTP.get_response(URI.parse(gurl))
                        gdata = gresp.body
                        gresult = JSON.parse(gdata)
			if not gresult['results'].first['formatted_address'].nil?
				puts gresult['results'].first['formatted_address']
				application[:address] = gresult['results'].first['formatted_address']
			end
		    end
		else 
		    application[:address] = result[0][:address]
		end
	end
    applications << application unless application[:address].nil?
    application = {date_scraped: Date.today}
  else
    if line.text.strip! == ""
      next
    end
    parts = line.text.split(":")
    if parts.length == 1
      current_suburb = line.text.strip!
    else
      case parts[0]
      when 'Development Application'
        application[:council_reference] = parts[1].strip!
      when 'Address'
        application[:address] = "#{parts[1..-1].join(":").strip!}, #{current_suburb}, ACT"
      when 'Block'
        application[:block] = parts[1].gsub(" Section","").strip!
        application[:section] = parts[2].strip!
        application[:suburb] = current_suburb
      when 'Proposal'
        application[:description] = parts[1..-1].join(":").strip!
      when 'Period for representations closes'
        application[:on_notice_to] = Date.parse(parts[1].strip, 'd/m/Y')
      end
    end

  end
end

applications.each do |record|
  if (ScraperWiki.select("* from data where `council_reference`='#{record[:council_reference]}'").empty? rescue true)
    ScraperWiki.save_sqlite([:council_reference], record)
  else
     puts "Skipping already saved record " + record[:council_reference]
  end
end
