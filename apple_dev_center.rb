#!/usr/bin/ruby
require 'rubygems'
require 'optparse'
require 'mechanize'
require 'json'
require 'yaml'
require 'encrypted_strings'

INSTALL_DIR = File.dirname($0)
USAGE =  "Usage: #{File.basename($0)} [-d [DIR]] [-u login] [-p password] [-O file] [-C config][-S secret_key] [-h]"

class Profile
  attr_accessor :uuid, :blobId, :type, :name, :appid, :statusXcode, :downloadUrl
  def to_json(*a)
    {
      'uuid' => uuid,
      'type' => type,
      'name' => name,
      'appid' => appid,
      'statusXcode' => statusXcode
#      'blobId' => blobId,      
#      'downloadUrl' => downloadUrl,
    }.to_json(*a)
  end
end

class Certificate
  attr_accessor :displayId, :type, :name, :exp_date, :profile, :status, :downloadUrl
  def to_json(*a)
    {
      'displayId' => displayId,
      'type' => type,
      'name' => name,
      'exp_date' => exp_date,
      'status' => status,
      'profile' => profile
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

def parse_config(options)
  config = YAML::load_file(options[:configFile])
  
  login_to_fetch = options[:login]
  if login_to_fetch.nil? 
    login_to_fetch = config['default']
  end
  account = config['accounts'].select { |a| a['login'] == login_to_fetch }[0]
  secret_key = options[:secretKey].nil? ? "" : options[:secretKey]
  encrypted = account['password']
  decrypted = encrypted.decrypt(:symmetric, :password => secret_key)
  options[:passwd] = decrypted
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
    opts.on( '-d', '--dump [DIR]', 'dumps the site content as JSON format (to the optional specified directory, that will be created if non existent)') do |dir|
      options[:dump] = true
      options[:dumpDir] = dir.nil? ? "." : dir
      if not File.exists?(options[:dumpDir])
        Dir.mkdir(options[:dumpDir])
      end
    end
    opts.on( '-S', '--seed SEED', 'the secret_key for the config file if required') do |secret_key|
      options[:secretKey] = secret_key.nil? ? "" : secret_key
    end
    opts.on( '-C', '--config FILE', 'fetch password (and optionally default user) information from the specified config file, with the optional secret_key') do |config_file, secret_key|
      options[:configFile] = config_file
      if not File.exists?(options[:configFile])
        raise OptionParser::InvalidArgument, "Specified '#{config_file}'file doesn't exists"
      end
    end
    opts.on( '-O', '--output FILE', 'writes output to the specified file. Uses standard output otherwise') do |output|
      options[:output] = output
    end
    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end    
  }.parse!(args)

  parse_config(options) unless options[:configFile].nil?

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

    @certificateUrls = {}
    @certificateUrls[:development] = "https://developer.apple.com/ios/manage/certificates/team/index.action"
    @certificateUrls[:distribution] = "https://developer.apple.com/ios/manage/certificates/team/distribute.action"

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

  def read_profiles(page, type)
    profiles = []
    # Format each row as name,udid
    rows = page.parser.xpath('//fieldset[@id="fs-0"]/table/tbody/tr')
    rows.each do |row|
      p = Profile.new()
      p.blobId = row.at_xpath('td[@class="checkbox"]/input/@value')
      p.type = type
      next if row.at_xpath('td[@class="profile"]/a/span').nil?
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
    @profileUrls.each { |type, url|
      info("Fetching #{type} profiles")
      page = load_page_or_login(url, options)
      all_profiles.concat(read_profiles(page, type))
    } 
    all_profiles
  end

  def read_certificates_distribution(page, type)
    certs = []
    # Format each row as name,udid  
    rows = page.parser.xpath('//div[@class="nt_multi"]/table/tbody/tr')
    rows.each do |row|
      last_elt = row.at_xpath('td[@class="action last"]')
      if last_elt.nil?
        msg_elt = row.at_xpath('td[@colspan="4"]/span')
        if !msg_elt.nil?
          info("-->#{msg_elt.text}")
        end
        next
      end
      next if last_elt.at_xpath('form').nil?
      c = Certificate.new()
      # :displayId, :type, :name, :exp_date, :profiles, :status, :downloadUrl
      c.downloadUrl = last_elt.at_xpath('a/@href')
      c.displayId = c.downloadUrl.to_s.split("certDisplayId=")[1]
      c.type = type
      c.name = row.at_xpath('td[@class="name"]/a').text
      c.exp_date = row.at_xpath('td[@class="expdate"]').text.strip
      # unsure if one certificate can be mapped to several profiles
      c.profile = row.at_xpath('td[@class="profile"]').text.strip
      c.status = row.at_xpath('td[@class="status"]').text.strip
      certs << c
    end
    certs
  end
  
  def read_certificates_development(page, type)
    certs = []
    # Format each row as name,udid  
    rows = page.parser.xpath('//div[@class="nt_multi"]/table/tbody/tr')
    rows.each do |row|
      last_elt = row.at_xpath('td[@class="last"]')
      next if last_elt.at_xpath('form').nil?
      c = Certificate.new()
      # :displayId, :type, :name, :exp_date, :profiles, :status, :downloadUrl
      c.downloadUrl = last_elt.at_xpath('a/@href')
      c.displayId = c.downloadUrl.to_s.split("certDisplayId=")[1]
      c.type = type
      c.name = row.at_xpath('td[@class="name"]/div/p').text
      c.exp_date = row.at_xpath('td[@class="date"]').text.strip
      # unsure if one certificate can be mapped to several profiles
      c.profile = row.at_xpath('td[@class="profiles"]').text.strip
      c.status = row.at_xpath('td[@class="status"]').text.strip
      certs << c
    end
    certs
  end  

  def read_all_certificates(options)
    all_certs = []
    info("Fetching development certificates")
    page = load_page_or_login(@certificateUrls[:development], options)    
    all_certs.concat(read_certificates_development(page, :development))
    info("Fetching distribution certificates")
    page = load_page_or_login(@certificateUrls[:distribution], options)    
    all_certs.concat(read_certificates_distribution(page, :distribution))
    all_certs
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
    site[:certificates] = read_all_certificates(options)

    download_profiles(site[:profiles], options[:dumpDir])
    download_certificates(site[:certificates], options[:dumpDir])
    
    site
  end
  
  # return the uuid of the specified mobile provisioning file
  def pp_uuid(ppfile)
    # FIXME extract script into a reusable ruby library    
    uuid = `#{INSTALL_DIR}/mobileprovisioning.rb #{ppfile} -d UUID`
    # strip trailing \n
    uuid = uuid[0..-2]
    uuid
  end
  
  def download_profiles(profiles, dumpDir)
    profiles.each do |p|
      filename = "#{dumpDir}/#{p.blobId}.mobileprovision"
      info("Downloading profile #{p.blobId} '#{p.name}'")
      @agent.download(p.downloadUrl, filename)
      uuid = pp_uuid filename 
      p.uuid = uuid
      newfilename = "#{dumpDir}/#{uuid}.mobileprovision"
      File.rename(filename, "#{newfilename}")
      info("Saved profile #{p.uuid} '#{p.name}' in #{newfilename}")
    end
  end

  def download_certificates(certs, dumpDir)
    certs.each do |c|
      filename = "#{dumpDir}/#{c.displayId}.cer"
      info("Downloading cert #{c.displayId} -#{c.type}- '#{c.name}'")
      @agent.download(c.downloadUrl, filename)
      info("Saved cert #{c.displayId} '#{c.name}' in #{filename}")
    end
  end
end

def dumpSite(options)
  @ADC = AppleDeveloperCenter.new()
  site = @ADC.fetch_site_data(options)
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