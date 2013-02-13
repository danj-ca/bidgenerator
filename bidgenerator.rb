require 'date'
require 'haml'
require 'rmagick'

include Magick

startTime = Time.now
pageTime = 0
stripTime = 0
puts "BiD Generator started at #{startTime}."
#Settings are hard-coded in the script for now. Eventually move to command-line and/or YAML file, perhaps

input_folder = './bidTestImages'
output_folder = "#{Dir.home}/Sites/bobisdoomed"
strip_blacklist = ['01-011', '01-014']
#Given a filename PATTERN, for eg. "bid_XX_YYY.jpg" where XX and YYY are monotonically-increasing volume and strip numbers, respectively
strip_filename_pattern = /bid_([0-9]{2})_([0-9]{3}).psd/
#Date that the first (earliest) strip should be posted
start_date = Date.parse('2012-12-26')
haml_template_filename = './bidTemplate.haml'
# post_weekdays contains a list of days of the week on which strips will be posted; (0 = Sunday, 1 = Monday, ... , 6 = Saturday)
post_weekdays = [1, 3, 5]

#test output settings
puts "# Settings"
puts "# input: #{input_folder} | output: #{output_folder} | strip pattern: #{strip_filename_pattern} | page template: #{haml_template_filename}"
puts "# start date: #{start_date} | post weekdays: #{post_weekdays} | blacklist: #{strip_blacklist} "
puts


def next_weekday(current_date, target_weekdays = [])
	if (target_weekdays.include?(current_date.wday))
		return current_date
	end
	
	return next_weekday(current_date.next_day, target_weekdays)
end

#Create a hash of the filenames in DIR that match PATTERN, in order of increasing XXXX-then-YYYY
#With hash keys that are dates such that the first item has a date of START_DATE, and
#Subsequent items n have a date-key calculated via function next_post_date(n-1)
template = File.read(haml_template_filename)

engine = Haml::Engine.new(template, { format: :html5 })

relevant_files = Dir.new(input_folder).select do |filename| 
	filename =~ strip_filename_pattern and !strip_blacklist.include?("#{$1}-#{$2}")
end.sort

puts "Found #{relevant_files.count} input files."

post_date = start_date
first_page = ''
#TODO restructure this, because if we can just pull all relevant files into a hash keyed by datestamp, a lot of the fiddly logic below goes away when we iterate over the hash instead. And I bet there's a one-liner to transform an array into a hash

relevant_files.each_with_index do |filename, index|

	volume, strip = filename.scan(strip_filename_pattern).flatten
	
	is_first = index == 0
	is_last = index == relevant_files.count - 1
	is_penultimate = index == relevant_files.count - 2
	
	if (!is_first)
		previous_post_date = post_date
		loop do
			previous_post_date = previous_post_date.prev_day
			break if post_weekdays.include?(previous_post_date.wday)
		end	
		
		previous_post_filename = "bid-#{previous_post_date.strftime("%Y-%m-%d")}.html"
	end
	
	if (!is_last)
		next_post_date = post_date
		loop do
			next_post_date = next_post_date.next_day
			break if post_weekdays.include?(next_post_date.wday)
		end	
		
		next_post_filename = "bid-#{next_post_date.strftime("%Y-%m-%d")}.html"
	end
	
	this_filename_token = "bid-#{post_date.strftime("%Y-%m-%d")}"

	strip_filename = "#{this_filename_token}.jpg"
	page_filename = "#{this_filename_token}.html"
	
	if (is_first)
		first_page = page_filename
	end
	
	puts "* Processing file #{index}:#{filename} (first: #{is_first} last: #{is_last} penultimate: #{is_penultimate} | strip: #{strip_filename} | page: #{page_filename} )"
	puts "** previous post: #{previous_post_date} (#{previous_post_filename}) | next post: #{next_post_date} (#{next_post_filename})"
### variables expected by the haml template:
# strip_filename
# strip_volume (as XX)
# strip_number (as XXX)
# post_date (date this strip is posted)
# prev_page (filename of previous page)
# next_page (filename of next page
# this_page (filename of this page)
# first_page (filename of the first page)
# is_last (boolean if this page is the last page)
# is_index (boolean if this page is the actual index.html page)
# is_first (boolean if this page is the first page)

	stopwatch = Time.now
	
	output = engine.render(Object.new, strip_filename: strip_filename, strip_volume: volume, strip_number: strip, post_date: post_date,
								   prev_page: previous_post_filename, next_page: next_post_filename, this_page: page_filename, first_page: first_page,
								   is_first: is_first, is_last: is_last, is_index: false)
								   	
	elapsed = Time.now - stopwatch
	pageTime += elapsed
	puts "*** Rendered #{page_filename} in #{elapsed} seconds."
	
	stopwatch = Time.now							   
	
	File.open("#{output_folder}/#{page_filename}", 'w') { |file| file.write(output) }
	
	elapsed = Time.now - stopwatch
	pageTime += elapsed
	puts "*** Wrote #{page_filename} in #{elapsed} seconds."
	
	# Generate the index page separately, so its "archive" page always exists
	if (is_last)
		output = engine.render(Object.new, strip_filename: strip_filename, strip_volume: volume, strip_number: strip, post_date: post_date,
									   prev_page: previous_post_filename, next_page: next_post_filename, this_page: page_filename, first_page: first_page,
									   is_first: is_first, is_last: is_last, is_index: true)
									   	
		elapsed = Time.now - stopwatch
		pageTime += elapsed
		puts "*** Rendered index.html in #{elapsed} seconds."
		
		stopwatch = Time.now							   
		
		File.open("#{output_folder}/index.html", 'w') { |file| file.write(output) }
		
		elapsed = Time.now - stopwatch
		pageTime += elapsed
		puts "*** Wrote index.html in #{elapsed} seconds."
	end
	
	if (!File.exists?("#{output_folder}/strips/#{strip_filename}"))
		stopwatch = Time.now
		
		inputImage = ImageList.new("#{input_folder}/#{filename}")
		
		elapsed = Time.now - stopwatch
		stripTime += elapsed
		puts "*** Read #{filename} in #{elapsed} seconds."
		
		stopwatch = Time.now
		
		inputImage[0].resize_to_fit(940).write("#{output_folder}/strips/#{strip_filename}")
		
		elapsed = Time.now - stopwatch
		stripTime += elapsed
		puts "*** Created and wrote #{strip_filename} in #{elapsed} seconds."
	end
	
	puts
	# puts "Volume: #{volume} Strip: #{strip} Post date: #{post_date}"
# 	puts "\tis first: #{is_first} is last: #{is_last}"
# 	puts "\tstrip: #{strip_filename}, page: #{page_filename}"
# 	puts "\tprevious page: #{previous_post_filename}, next page: #{next_post_filename}"

	post_date = next_post_date
		
end #relevant_files.each_with_index


puts "BiD Generator finished processing #{relevant_files.count} strips in #{Time.now - startTime} seconds."
puts "Time spent rendering pages: #{pageTime} seconds | Time spent exporting images: #{stripTime} seconds."