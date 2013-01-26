require 'haml'
require 'yaml'
require 'rmagick'

include Magick

settings = YAML.load_file("./generator_settings.yml")

# Grab settings into local variables

input_folder = settings['input_folder']
output_folder = settings['output_folder']
strip_blacklist = settings['blacklist']
#Given a filename PATTERN, for eg. "bid_XX_YYY.jpg" where XX and YYY are monotonically-increasing volume and strip numbers, respectively
strip_filename_pattern = settings['strip_filename_pattern']
#Date that the first (earliest) strip should be posted
start_date = settings['start_date']
haml_template_filename = settings['page_template']
post_weekdays = settings['post_weekdays']

#test output settings
puts settings


def next_weekday(current_date, target_weekdays = [])
	if (target_weekdays.include?(current_date.wday))
		return current_date
	end
	
	return next_weekday(current_date.next_day, target_weekdays)
end

#Create a hash of the filenames in DIR that match PATTERN, in order of increasing XXXX-then-YYYY
#With hash keys that are dates such that the first item has a date of START_DATE, and
#Subsequent items n have a date-key calculated via function next_post_date(n-1)
template = File.read("#{input_folder}/#{haml_template_filename}")

engine = Haml::Engine.new(template, { format: :html5 })

relevant_files = Dir.new(input_folder).select do |filename| 
	filename =~ strip_filename_pattern and !strip_blacklist.include?("#{$1}-#{$2}")
end.sort

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
		
		next_post_filename = (is_penultimate) ? "index.html" : "bid-#{next_post_date.strftime("%Y-%m-%d")}.html"
	end
	
	
	this_filename_token = "bid-#{post_date.strftime("%Y-%m-%d")}"

	strip_filename = "#{this_filename_token}.jpg"
	page_filename = (is_last) ? "index.html" : "#{this_filename_token}.html"
	
	if (is_first)
		first_page = page_filename
	end
	
### variables expected by the haml template:
# strip_filename
# strip_volume (as XX)
# strip_number (as XXX)
# post_date (date this strip is posted)
# prev_page (filename of previous page)
# next_page (filename of next page
# this_page (filename of this page)
# first_page (filename of the first page)
# is_last (boolean if this page is the index (last) page)
# is_first (boolean if this page is the first page)

	output = engine.render(Object.new, strip_filename: strip_filename, strip_volume: volume, strip_number: strip, post_date: post_date,
								   prev_page: previous_post_filename, next_page: next_post_filename, this_page: page_filename, first_page: first_page,
								   is_first: is_first, is_last: is_last)
								   
	File.open("#{output_folder}/#{page_filename}", 'w') { |file| file.write(output) }
	inputImage = ImageList.new("#{input_folder}/#{filename}")
	inputImage[0].resize_to_fit(940).write("#{output_folder}/strips/#{strip_filename}")

	# puts "Volume: #{volume} Strip: #{strip} Post date: #{post_date}"
# 	puts "\tis first: #{is_first} is last: #{is_last}"
# 	puts "\tstrip: #{strip_filename}, page: #{page_filename}"
# 	puts "\tprevious page: #{previous_post_filename}, next page: #{next_post_filename}"

	post_date = next_post_date
		
end #relevant_files.each_with_index





#For each entry in the hash
#Apply TEMPLATE to generate a file OUTPUT

#Where OUTPUT is an HTML file named using the pattern "bid_XXXX_YYYY.html" (or should we use the datestamp for some reason?)

#Where TEMPLATE is such that OUTPUT links to the filename of the current hash entry (with an appropriate relative path to the remote images folder)
#And the Next and Previous (and perhaps First, etc.) links reference the appropriate pages (this is where it may be sensible to use dates in the page names, because we can easily get the next/previous keys from the hash)
#And the page contains the DISQUS id and other page-specific identifiers needed for integration with other services
#These must be generated consistently for a given strip, so should probably use its strip ID, not the date, so that the appropriate comments always stay on each strip

#UNLESS the entry in the hash is the last entry, in which case,
#Apply template, but name the OUTPUT file "index.html", possibly applying a different TEMPLATE (or at least different partials) for whatever styling we only want on the frontpage (don't have a Next Strip link, etc. 

#Maybe have a blog?
#If we have a blog, should use some text template format (YAML?) and just save text files in a separately-specified or sub-folder from DIR
#Align blogs with specific strips (or specific dates, optionally?) and have a place in the TEMPLATE where any related blog content goes?
#If we have a blog at all, it should be brief, or link to a longer article elsewhere (my blog or Chris's; if we wants to post about art, perhaps we should have people go offsite to his own blog for that? Discuss with Steph.)




