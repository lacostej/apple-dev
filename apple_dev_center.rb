#!/usr/bin/ruby
require 'rubygems'
require 'optparse'
require 'mechanize'
require 'json'

USAGE =  "Usage: #{File.basename($0)} [-d] [-u login] [-p password] [-O file] [-h]"

class Profile
  attr_accessor :blobId, :name, :appid, :statusXcode, :downloadUrl
  def to_json(*a)
    {
      'blobId' => blobId,
      'name' => name,
      'appid' => appid,
      'statusXcode' => statusXcode
#      'downloadUrl' => downloadUrl,
    }.to_json(*a)
  end
end

class Device
  attr_accessor :udid, :name
  def to_json(*a)
    {
      'udid' => udid,
      'name' => name
    }.to_json(*a)
  end
end

def info(message)
  puts message
end

def parse_command_line(args)
  options = {}

  OptionParser.new { |opts|
    opts.banner = USAGE
    
    opts.on( '-u', '--user USER', 'the apple developer store login') do |login|
      options[:login] = login
    end
    opts.on( '-p', '--password PASSWORD', 'the apple developer store login') do |passwd|
      options[:passwd] = passwd
    end
    opts.on( '-d', '--dump', 'dumps the site content as JSON format') do |key|
      options[:dump] = true
    end
    opts.on( '-O', '--output FILE', 'writes output to the specified file. Uses standard output otherwise') do |output|
      options[:output] = output
    end
    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end    
  }.parse!(args)

  options
end


def dump(text, file)
  if (file)
    File.open(file, 'w') { |f| f.write(text) }
  else
    puts text
  end
end

class AppleDeveloperCenter
  def initialize
    @agent = Mechanize.new
    @profileUrls = {}
    @profileUrls[:development] = "https://developer.apple.com/ios/manage/provisioningprofiles/index.action"
    @profileUrls[:distribution] = "https://developer.apple.com/ios/manage/provisioningprofiles/viewDistributionProfiles.action"

    @devicesUrl = "https://developer.apple.com/ios/manage/devices/index.action"
  end
  
  def load_page_or_login(url, options)
    #info "Loading #{url}"
    page = @agent.get(url)

    # Log in to Apple Developer portal if we're presented with a login form
    form = page.form_with :name => 'appleConnectForm'
    if form
      form.theAccountName = options[:login]
      form.theAccountPW = options[:passwd]
      form.submit
      page = @agent.get(url)
    end
    page
  end

  def read_profiles(page)
    profiles = []
    # Format each row as name,udid
    rows = page.parser.xpath('//fieldset[@id="fs-0"]/table/tbody/tr')
    rows.each do |row|
      p = Profile.new()
      p.blobId = row.at_xpath('td[@class="checkbox"]/input/@value')
      p.name = row.at_xpath('td[@class="profile"]/a/span').text
      p.appid = row.at_xpath('td[@class="appid"]/text()')
      p.statusXcode = row.at_xpath('td[@class="statusXcode"]').text.strip.split("\n")[0]
      p.downloadUrl = row.at_xpath('td[@class="action"]/a/@href')
      profiles << p
    end
    profiles
  end  

  def read_all_profiles(options)
    all_profiles = []
    @profileUrls.each { |key, url|
      info("Fetching #{key} profiles")
      page = load_page_or_login(url, options)
      all_profiles.concat(read_profiles(page))
    } 
    all_profiles
  end

  def read_devices(options)
    info("Fetching devices")
    page = load_page_or_login(@devicesUrl, options)
  
    devices = []
    rows = page.parser.xpath('//fieldset[@id="fs-0"]/table/tbody/tr')
    rows.each do |row|
      d = Device.new()
      d.name = row.at_xpath('td[@class="name"]/span/text()')
      d.udid = row.at_xpath('td[@class="id"]/text()')
      devices << d
    end
    devices
  end

  def fetch_site_data(options)
    site = {}
    site[:devices] = read_devices(options)
    site[:profiles] = read_all_profiles(options)
    site
  end
  
  def download_profiles(profiles)
    profiles.each do |p|
      filename = "#{p.blobId}.mobileprovision"
      info("Saving profile #{p.blobId} '#{p.name} ' in #{filename}")
      @agent.download(p.downloadUrl, filename)
    end
  end
end

def dumpSite(options)
  @ADC = AppleDeveloperCenter.new()
  site = @ADC.fetch_site_data(options)
  @ADC.download_profiles(site[:profiles])
  text = site.to_json
  dump(text, options[:output])
end

def main()
  begin
    options = parse_command_line(ARGV)
  rescue OptionParser::ParseError => e
    puts "Invalid argument: #{e}"
    puts "#{USAGE}"
    exit 1
  end

  if (options[:dump])
    dumpSite(options)
  end
  
end

main()