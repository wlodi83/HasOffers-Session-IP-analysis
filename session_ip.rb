require 'date'
require 'time'
require File.join(File.dirname(__FILE__), 'lib/requester')
require 'spreadsheet'
require 'yaml'
require 'yajl'
#require 'rubygems'
#require 'gruff'

#load hasoffers config
config = YAML.load_file("config/config.yaml")
network_id = config["network_id"]
network_token = config["network_token"]
url = config["url"]

#Create result file
result = Spreadsheet::Workbook.new
sheet1 = result.create_worksheet
sheet1.name = 'SessionIP'
sheet1.row(0).concat %w{ip approved rejected revenue}

row_counter = 1

#HasOffers request hash

ho_request = {
  "NetworkId" => network_id,
  "NetworkToken" => network_token,
  "Target" => "Report",
  "Method" => "getConversions",
  "fields[0]" => "Stat.session_ip",
  "fields[1]" => "Stat.status",
  "fields[2]" => "Stat.payout",
  "fields[3]" => "Stat.offer_id",
  "fields[4]" => "Stat.country_code",
  "fields[5]" => "Browser.display_name",
  "fields[6]" => "Stat.status_code",
  "filters[Stat.date][conditional]" => "BETWEEN",
  "filters[Stat.date][values][0]" => start,
  "filters[Stat.date][values][1]" => start,
  "limit" => "100000",
  "page" => "1",
  "totals" => "1"
}

hour_hash = {
  "filters[Stat.hour][conditional]" => "EQUAL_TO",
  "filters[Stat.hour][values][0]" => last_hour
}

case ARGV[0]
when "last_hour"
  time = Time.now
  last_hour = (time.hour - 1)
  start = time.strftime("%Y-%m-%d")
  response = Requester.make_request(
    url,
    ho_request.merge(hour_hash),
    :get
  )
when "yesterday"
  start = (Time.now - 86400).strftime("%Y-%m-%d")
  response = Requester.make_request(
    url,
    ho_request,
    :get
  )
when "today"
  start = Time.now.strftime("%Y-%m-%d")
  start = (Time.now - 86400).strftime("%Y-%m-%d")
  response = Requester.make_request(
    url,
    ho_request,
    :get
  )
else
  STDOUT.puts <<-EOF
  Please provide command name

  Usage:
    ruby session_ip.rb last_hour
    ruby session_ip.rb today
    ruby session_ip.rb yesterday
  EOF
end

#Advertiser Stuff
#advertiser_id = "679"
#advertiser_company = "Clicktron S.L."

#"filters[Advertiser.id][conditional]" => "EQUAL_TO",
#"filters[Advertiser.id][values][0]" => advertiser_id,
#"filters[Advertiser.company][conditional]" => "EQUAL_TO",
#"filters[Advertiser.company][values][0]" => advertiser_company,

#Parse JSON data

puts response

json = StringIO.new(response)
parser = Yajl::Parser.new
hash = parser.parse(json)

#iparray= Array.new

#hash["response"]["data"]["data"].each do |ip|
#  iparray << ip["Stat"]["session_ip"]
#end

#iparray.uniq!

#result_array = Array.new

#start_day = (Time.now).strftime("%Y-%m-%d")
#end_day = (Time.new().to_datetime >> -1).strftime("%Y-%m-%d")

#iparray.each do |ip|
#    response = Requester.make_request(
#      url,
#      {
#      "NetworkId" => network_id,
#      "NetworkToken" => network_token,
#      "Target" => "Report",
#      "Method" => "getConversions",
#      "fields[0]" => "Stat.session_ip",
#      "fields[1]" => "Stat.ip",
#      "fields[2]" => "Stat.status",
#      "fields[3]" => "Stat.offer_id",
#      "fields[4]" => "Stat.country_code",
#      "fields[5]" => "Stat.payout",
#      "filters[Stat.session_ip][conditional]" => "EQUAL_TO",
#      "filters[Stat.session_ip][values][]" => "#{ip}",
#      "filters[Stat.date][conditional]" => "BETWEEN",
#      "filters[Stat.date][values][0]" => end_day,
#      "filters[Stat.date][values][1]" => start_day,
#      "limit" => "50000",
#      "page" => "1",
#      "totals" => "1",
#      },
#      :get
#    )

#    if response
#      json = StringIO.new(response)
#      parser = Yajl::Parser.new
#      ip_hash = parser.parse(json)
#      ip_info = ip_hash["response"]["data"]["data"]
#      approved = 0
#      rejected = 0
#      revenue = 0
#      session_ip = []
#      ip_info.each do |ii|
#        if ii["Stat"]["status"] == "approved"
#          approved += 1
#          revenue += ii["Stat"]["payout"].to_f
#        else
#          rejected += 1
#        end
#      end
#      result_array.push(["#{ip}", approved, rejected, revenue]) if approved > 10 or rejected > 10 or revenue > 10
#    end
#end

#g = Gruff::Line.new
#g.title = "HasOffers Session IP Graph"

#rev_graph = []
#app_graph = []
#rej_graph = []
#ip_graph = []

#result_array.each do |row|
 # sheet1.row(row_counter).push row[0], row[1], row[2], row[3]
 # row_counter += 1
  #ip_graph << row[0]
  #app_graph << row[1]
  #rej_graph << row[2]
  #rev_graph << row[3]
#end

#g.data("Approved", app_graph)
#g.data("Rejected", rej_graph)
#g.data("Revenue", rev_graph)

#g.marker_count = 3 #explicitly assign value to @marker_count

#size = ip_graph.size

#(1..size).each do |i|
#  g.labels = {"#{i}" => "#{ip_graph[i-1]}"}
#end

#g.write('graph.png')
result.write 'ho_fraud_report.xls'
