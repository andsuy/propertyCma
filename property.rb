class Property < ActiveRecord::Base
require 'csv'
require 'geocoder'
require 'watir-webdriver'

scope :zip,   -> (zip) {where zip: zip}
scope :zip,   -> (zip) {where zip: zip}
reverse_geocoded_by :lat, :lng
after_validation :reverse_geocode 
	
	def Property.browser_init()
		#initialize download directory and browser
		download_directory = "#{Dir.pwd}/downloads"
		download_directory.gsub!("/", "\\") if Selenium::WebDriver::Platform.windows?

		profile = Selenium::WebDriver::Firefox::Profile.new
		profile['browser.download.dir'] = download_directory
		profile['browser.helperApps.neverAsk.saveToDisk'] = "text/csv,application/pdf"

		browser = Watir::Browser.new :firefox, :profile => profile #start new browser to scrape
		return browser
	end

	def Property.mls_init(params)
		browser = Property.browser_init()
		site = 'https://www.mls.com' #mls site placeholder
		username = 'example@mail.com'
		password = 'password'
		#go to site, log in
		browser.goto site
		browser.text_field(name: 'SignInEmail').set username
    browser.text_field(name: 'SignInPassword').set password
    browser.link(id: 'SignInBtn').click
    Property.mls_scrape(browser, params)
	end

	def Property.select_params(browser, params)
		#
		browser.select_list(:id, "PropertyType").select_value(params[0])
		browser.select_list(:id, "City").select_value(params[1])
		browser.text_field(:id, "SqFtRange").set params[2]
		browser.text_field(:id, "Price").set params[3]
	end

	def Property.mls_scrape(browser, params)
		site = 'https://www.mls.com/search' #another placeholder site
		Property.select_params(browser, params)
		browser.link(id: 'Search').click
		browser.link(id: 'Download').click
		Property.import_csv("#{Dir.pwd}/downloads/mls_info.csv")
		browser.close
	end


	def Property.import_csv(filename)
		CSV.foreach(filename, :headers => true) do |row|
	  	Property.create!(row.to_hash)
		end
	end

	def Property.inArea(address, distance, range)
		date = DateTime.now.beginning_of_day.yesterday
		@properties = Property.where("sqft > ? AND sqft < ? AND cma=? AND created_at>? AND  year>? AND year<?", address.sqft-range, address.sqft+range, false, date, address.year-10, address.year+30)
		@properties = @properties.near([address.lat, address.lng], distance)
		if (@properties.length<2)
			@properties = Property.inArea(address, distance+0.1, range+10)
		end
		return @properties
	end

	def Property.makeURL(prop, orig)
		url = "http://cma.com/cmas/new?mlsnums=" #site API needs urls to generate CMAs.
		prop.each do |f|
			url = url + f.mlsnum.to_s + ","
		end
		url = url.chop
		url = url + "&title="+ orig.street_num.to_s + "+" + orig.street_name + "+" + orig.street_type + "&sqft=" + orig.sqft.to_s + "&beds=" + orig.bed.to_s + "&baths=" + orig.bath.to_s
		url = url + "&address=" + orig.street_num.to_s + "+" + orig.street_name + "+" +orig.street_type + ",+" + orig.city + ",CA+" + orig.zip.to_s
		return url

	end
	
  def Property.findAllProps(props)
  	urls = Array.new
  	props.each do |f|
  		comps = Property.inArea(f, 0.3, 250)
  		url = Property.makeURL(comps, f)
  		urls.push(url)
  	end
  	Property.writeToCsv(urls)
  end


	def Property.writeToCsv(urls)
		date = DateTime.now
		day = date.day
		month = date.month
		file = "cma_output_#{month}_#{day}.csv"
		CSV.open( file, 'w' ) do |writer|
 			 urls.each do |c|
  		 	writer << [c]
  		end
		end
	end

	
end
