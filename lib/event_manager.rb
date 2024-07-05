require "csv"
require "google/apis/civicinfo_v2"
require "erb"

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phone_number(number)
  number = number.tr("^0-9", "")

  return number if number.length == 10

  return number[1..10] if number.length == 11 && number[0] == "1"

  "Bad number"
end

def get_registration_hour(time)
  time = time.split(/\D/)
  time[3]
end

def get_registration_day(time)
  time = time.split[0].split("/")
  time = Time.new(time[2], time[0], time[1])
  time.strftime("%A")
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read("key.txt").strip

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: "country",
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  FileUtils.mkdir_p("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

puts "Event Manager Initialized!"

contents = CSV.open(
  "event_attendees.csv",
  headers: true,
  header_converters: :symbol
)

template_letter = File.read("form_letter.erb")
erb_template = ERB.new template_letter

hours = Hash.new(0)
days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])
  number = clean_phone_number(row[:homephone])

  date = row[:regdate]

  registration_hour = get_registration_hour(date)
  hours[registration_hour.to_sym] += 1

  registration_day = get_registration_day(date)
  days[registration_day.to_sym] += 1

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

hours = hours.sort_by { |_, value| value }
hours.each { |key, value| puts "#{key}: #{value}" }

puts

days = days.sort_by { |_, value| value }
days.each { |key, value| puts "#{key}: #{value}" }
