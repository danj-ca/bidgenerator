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

# what ought to be encapsulated in a strip class?
# - volume, strip numbers
# - post date
# - id of next, previous strips, if any
# - getters to spit name of current strip, page, image, prev / next pages
# - is_first, is_last
class Strip
	attr_reader :volume_number, :strip_number, :post_date, :prev_date, :next_date, :is_first, :is_last
	
	def initialize(voln, stripn, pdate, prev_date, next_date, is_first, is_last)
		@volume_number = voln
		@strip_number = stripn
		@post_date = pdate
		@next_date = next_date
		@prev_date = prev_date
		@is_first = is_first
		@is_last = is_last
	end
	
	def identifier
		"#{@volume_number}-#{@strip_number}"
	end
	
	def image_name
		"bid-#{@post_date.strftime("%Y-%m-%d")}.jpg"
	end
	
	def page_name
		"bid-#{@post_date.strftime("%Y-%m-%d")}.html"
	end
	
	def prev_page_name
		if @prev_date
			"bid-#{@prev_date.strftime("%Y-%m-%d")}.html"
		else
			nil
		end
	end
	
	def next_page_name
		if @next_date
			"bid-#{@next_date.strftime("%Y-%m-%d")}.html"
		else
			nil
		end
	end
	
	def to_s
		"Strip #{identifier}: #{page_name} first: #{is_first} prev: #{prev_page_name} last: #{is_last} next: #{next_page_name}"
	end
end

relevant_files.each_with_index do |filename, index|

	volume, strip = filename.scan(strip_filename_pattern).flatten
	
	is_first = index == 0
	is_last = index == relevant_files.count - 1
	
	if (!is_first)
		previous_post_date = post_date
		loop do
			previous_post_date = previous_post_date.prev_day
			break if post_weekdays.include?(previous_post_date.wday)
		end	
	end
	
	if (!is_last)
		next_post_date = post_date
		loop do
			next_post_date = next_post_date.next_day
			break if post_weekdays.include?(next_post_date.wday)
		end	
	end
	
	current_strip = Strip.new(volume, strip, post_date, previous_post_date, next_post_date, is_first, is_last)
		
	if (is_first)
		first_page = current_strip.page_name
	end
	
	puts "* Processing file #{index}:#{filename} (#{current_strip.to_s})"

	stopwatch = Time.now
	
	output = engine.render(Object.new, 
						   strip_filename: current_strip.image_name, 
						   strip_volume: current_strip.volume_number, 
						   strip_number: current_strip.strip_number, 
						   post_date: current_strip.post_date,
						   prev_page: current_strip.prev_page_name, 
						   next_page: current_strip.next_page_name, 
						   this_page: current_strip.page_name, 
						   first_page: first_page,
						   is_first: current_strip.is_first, 
						   is_last: current_strip.is_last, 
						   is_index: false)
								   	
	elapsed = Time.now - stopwatch
	pageTime += elapsed
	puts "*** Rendered #{current_strip.page_name} in #{'%.3f' % elapsed} seconds."
	
	stopwatch = Time.now							   
	
	File.open("#{output_folder}/#{current_strip.page_name}", 'w') { |file| file.write(output) }
	
	elapsed = Time.now - stopwatch
	pageTime += elapsed
	puts "*** Wrote #{current_strip.page_name} in #{'%.3f' % elapsed} seconds."
	
	# Generate the index page separately, so its "archive" page always exists
	if (is_last)
	output = engine.render(Object.new, 
						   strip_filename: current_strip.image_name, 
						   strip_volume: current_strip.volume_number, 
						   strip_number: current_strip.strip_number, 
						   post_date: current_strip.post_date,
						   prev_page: current_strip.prev_page_name, 
						   next_page: current_strip.next_page_name, 
						   this_page: current_strip.page_name, 
						   first_page: first_page,
						   is_first: current_strip.is_first, 
						   is_last: current_strip.is_last, 
						   is_index: true)
									   	
		elapsed = Time.now - stopwatch
		pageTime += elapsed
		puts "*** Rendered index.html in #{'%.3f' % elapsed} seconds."
		
		stopwatch = Time.now							   
		
		File.open("#{output_folder}/index.html", 'w') { |file| file.write(output) }
		
		elapsed = Time.now - stopwatch
		pageTime += elapsed
		puts "*** Wrote index.html in #{'%.3f' % elapsed} seconds."
	end
	
	if (!File.exists?("#{output_folder}/strips/#{current_strip.image_name}"))
		stopwatch = Time.now
		
		inputImage = ImageList.new("#{input_folder}/#{filename}")
		
		elapsed = Time.now - stopwatch
		stripTime += elapsed
		puts "*** Read #{filename} in #{'%.3f' % elapsed} seconds."
		
		stopwatch = Time.now
		
		inputImage[0].resize_to_fit(940).write("#{output_folder}/strips/#{current_strip.image_name}")
		
		elapsed = Time.now - stopwatch
		stripTime += elapsed
		puts "*** Created and wrote #{current_strip.image_name} in #{'%.3f' % elapsed} seconds."
	end

	puts

	post_date = next_post_date
		
end #relevant_files.each_with_index


puts "BiD Generator finished processing #{relevant_files.count} strips in #{'%.3f' % (Time.now - startTime)} seconds."
puts "Time spent rendering pages: #{'%.3f' % pageTime} seconds | Time spent exporting images: #{'%.3f' % stripTime} seconds."