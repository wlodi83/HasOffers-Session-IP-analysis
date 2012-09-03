require 'date'
require 'time'
require File.join(File.dirname(__FILE__), 'lib/requester')
require 'spreadsheet'
require 'yaml'
require 'yajl'

#load hasoffers config
config = YAML.load_file("config/config.yaml")
network_id = config["network_id"]
network_token = config["network_token"]
url = config["url"]

#Create result file
result_sheet = Spreadsheet::Workbook.new
sheet1 = result_sheet.create_worksheet
sheet1.name = 'SessionIP'
sheet1.row(0).concat %w{ip approved approved_revenue approved_browsers approved_offers rejected rejected_revenue rejected_browsers rejected_offers rejected_statuses}

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
  "limit" => "100000",
  "page" => "1",
  "totals" => "1"
}

case ARGV[0]
when "last_hour"
  time = Time.now
  last_hour = (time.hour - 1)
  start = time.strftime("%Y-%m-%d")
  response = Requester.make_request(
    url,
    ho_request.merge( 
      {
        "filters[Stat.date][values][0]" => start,
        "filters[Stat.date][values][1]" => start,
        "filters[Stat.hour][conditional]" => "EQUAL_TO",
        "filters[Stat.hour][values][0]" => last_hour
      }
    ),
    :get
  )
when "yesterday"
  start = (Time.now - 86400).strftime("%Y-%m-%d")
  response = Requester.make_request(
    url,
    ho_request.merge(
      {
        "filters[Stat.date][values][0]" => start,
        "filters[Stat.date][values][1]" => start
      }
    ),
    :get
  )
when "today"
  start = Time.now.strftime("%Y-%m-%d")
  response = Requester.make_request(
    url,
    ho_request.merge(
      {
        "filters[Stat.date][values][0]" => start,
        "filters[Stat.date][values][1]" => start
      }
    ),
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

#Parse JSON data
json = StringIO.new(response)
parser = Yajl::Parser.new
hash = parser.parse(json)

result = [] 

hash["response"]["data"]["data"].each do |data|
  result << [data["Stat"]["session_ip"], data["Stat"]["status"], data["Stat"]["payout"], data["Stat"]["offer_id"], data["Stat"]["status_code"], data["Browser"]["display_name"]]
end

approved = rejected = app_payout = rej_payout = 0
app_offer_id = []
rej_offer_id = []
app_browser = []
rej_browser = []
rej_status_code = []

grouped = result.group_by {|ip| ip[0]}
grouped.each do |key, value|
  approved = rejected = app_payout = rej_payout = 0
  app_offer_id = []
  rej_offer_id = []
  app_browser = []
  rej_browser = []
  rej_status_codes = []

  if value.size > 1
    value.each do |value_item|
      if value_item[1] == "approved"
        approved += 1
        app_browser << value_item[5]
        app_offer_id << value_item[3]
        app_payout += value_item[2].to_f
      else
        rejected += 1
        rej_browser << value_item[5]
        rej_offer_id << value_item[3]
        rej_payout += value_item[2].to_f
        rej_status_codes << value_item[4]
      end
    end
 
    app_browsers = app_browser.uniq.size > 1 ? app_browser.uniq.join(", ") : app_browser.uniq[0]
    app_offers_id = app_offer_id.uniq.size > 1 ? app_offer_id.uniq.join(", ") : app_offer_id.uniq[0]
    rej_browsers = rej_browser.uniq.size > 1 ? rej_browser.uniq.join(", ") : rej_browser.uniq[0]
    rej_offers_id = rej_offer_id.uniq.size > 1 ? rej_offer_id.uniq.join(", ") : rej_offer_id.uniq[0]

    #statuses variables
    kp = dc = nru = sinw = wtp = apld = dcce = dcbui = et = at = cae = cct = sct = spt = rt = adj = mcce = dpbe = mpbe = drbe = mrbe = amcce = adpbe = ampbe = adrbe = amrbe = cssir = uk = 0

    rej_status_codes.each do |status|
      code = status

      case code
      when '11'
        kp += 1
      when '12'
        dc += 1
      when '13'
        nru += 1
      when '14'
        sinw += 1
      when '15'
        wtp += 1
      when '16'
        apld +=1
      when '17'
        dcce += 1
      when '18'
        dcbui +=1
      when '21'
        et += 1
      when '22'
        at += 1
      when '31'
        cae += 1
      when '41'
        cct += 1
      when '42'
        sct += 1
      when '43'
        spt += 1
      when '51'
        rt += 1
      when '52'
        adj += 1
      when '61'
        mcce += 1
      when '62'
        dpbe += 1
      when '63'
        mpbe += 1
      when '64'
        drbe += 1
      when '65'
        mrbe += 1
      when '81'
        amcce += 1
      when '82'
        adpbe += 1
      when '83'
        ampbe += 1
      when '84'
        adrbe += 1
      when '85'
        amrbe += 1
      when '99'
        cssir += 1
      else
        uk += 1
        puts "Unknown statu: #{code}"
      end
    end

    status_result = Hash.new
  
    status_result = { "Known Proxy" => kp, "Duplicate Conversion by Transaction ID" => dc, "No Referral URL" => nru, "Server IP not Whitelisted" => sinw, "Wrong Tracking Protocol" => wtp, "Affiliate Pixel Loop Detected" => apld, "Daily Conversion Cap Exceeded" => dcce, "Duplicate Conversion by Unique ID" => dcbui, "Employee Test" => et, "Affiliate Test" => at, "Conversion approval enabled" => cae, "Client cookie tracking" => cct, "Server cookie tracking" => sct, "Server postback tracking" => spt, "RingRevenue tracking" => rt, "Adjustment" => adj, "Monthly Conversion Cap Exceeded" => mcce, "Daily Payout Budget Exceeded" => dpbe, "Monthly Payout Budget Exceeded" => mpbe, "Daily Revenue Budget Exceeded" => drbe, "Monthly Revenue Budget Exceeded" => mrbe, "Affiliate Monthly Conversion Cap Exceeded" => amcce, "Affiliate Daily Payout Budget Exceeded" => adpbe, "Affiliate Monthly Payout Budget Exceeded" => ampbe, "Affiliate Daily Revenue Budget Exceeded" => adrbe, "Affiliate Monthly Revenue Budget Exceeded" => amrbe, "Conversion Status set in Request" => cssir, "Unknown Status" => uk }

    status_result.delete_if {|key, value| value == 0}
    status_res = String.new
    status_result.each {|key, value| status_res << "#{key}: #{value}, "}

    if app_payout > 25 or rej_payout > 25
      sheet1.row(row_counter).push key, approved, app_payout, app_browsers, app_offers_id, rejected, rej_payout, rej_browsers, rej_offers_id, status_res.chop.chop
      row_counter += 1
    end
 end
end

result_sheet.write 'ho_fraud_report.xls'
