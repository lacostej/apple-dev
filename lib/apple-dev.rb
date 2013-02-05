#require "apple-dev/version"
require 'mechanize'
require 'json'
require 'plist'
#require 'logger' # Use this to log mechanize.

module Apple
  module Dev
	class Profile
	  attr_accessor :uuid, :blob_id, :type, :name, :appid, :statusXcode, :download_url
	  def to_json(*a)
	    {
	      'uuid' => uuid,
	      'type' => type,
	      'name' => name,
	      'appid' => appid,
	      'statusXcode' => statusXcode
	#      'blob_id' => blob_id,      
	#      'download_url' => download_url,
	    }.to_json(*a)
	  end
	end

	class Certificate
	  attr_accessor :displayId, :type, :name, :exp_date, :profile, :status, :download_url
	  def to_json(*a)
	    {
	      'displayId' => displayId,
	      'type' => type,
	      'name' => name,
	      'exp_date' => exp_date,
	      'status' => status,
	      'profile' => profile
	#      'download_url' => download_url,
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


	class IOSProvisioningPortal
	  def initialize(options)
	    @agent = Mechanize.new
	    @agent.pluggable_parser.default = Mechanize::File
	    #@agent.log = Logger.new('mechanize.log')
	    
	    # Set proxy if environment variable 'https_proxy' is set.
	    proxy_regex = /:\/\/(.[^:]*):(\d*)/
	    if ENV['https_proxy'] != nil && ENV['https_proxy'].match(proxy_regex) 
	      @agent.set_proxy(Regexp.last_match(1), Regexp.last_match(2))
	    end
	    
	    @apple_cert_url = "http://www.apple.com/appleca/AppleIncRootCertificate.cer"
	    
	    @profile_urls = {}
	    @profile_urls[:development] = "https://developer.apple.com/ios/manage/provisioningprofiles/index.action"
	    @profile_urls[:distribution] = "https://developer.apple.com/ios/manage/provisioningprofiles/viewDistributionProfiles.action"

	    @certificate_urls = {}
	    @certificate_urls[:development] = "https://developer.apple.com/ios/manage/certificates/team/index.action"
	    @certificate_urls[:distribution] = "https://developer.apple.com/ios/manage/certificates/team/distribute.action"

	    @devices_url = "https://developer.apple.com/ios/manage/devices/index.action"

	    @login = options[:login]
	    @passwd = options[:passwd]
	    @login = options[:login]
	    @teamid = options[:teamid]
	    @teamname = options[:teamname]
	    @dumpDir = options[:dumpDir]
	  end

	  def load_page_or_login(url)
	    page = @agent.get(url)

	    # Log in to Apple Developer portal if we're presented with a login form.
	    form = page.form_with(:name => 'appleConnectForm')
	    if form
	      info "Logging in with Apple ID '#{@login}'."
	      form.theAccountName = @login
	      form.theAccountPW = @passwd
	      form.submit
	      page = @agent.get(url)
	    end
	    page

	    # Select a team if you belong to multiple teams.
	    form = page.form_with(:name => 'saveTeamSelection')
	    if form
	      team_list = form.field_with(:name => 'memberDisplayId')
	      if @teamid.nil? || @teamid == ''
	        if @teamname.nil? || @teamname == ''
	          # Select first team if teamid and teamname are empty.
	          team_option = team_list.options.first
	        else
	          # Select team by name.
	          team_option = team_list.option_with(:text => @teamname)
	        end
	      else
	        # Select team by id.
	        team_option = team_list.option_with(:value => @teamid)
	      end

	      info "Selecting team '#{team_option.text}' (ID: #{team_option.value})."
	      team_option.select
	      btn = form.button_with(:name => 'action:saveTeamSelection!save')
	      form.click_button(btn)
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
	      p.blob_id = row.at_xpath('td[@class="checkbox"]/input/@value')
	      p.type = type
	      next if row.at_xpath('td[@class="profile"]/a/span').nil?
	      p.name = row.at_xpath('td[@class="profile"]/a/span').text
	      p.appid = row.at_xpath('td[@class="appid"]/text()')
	      p.statusXcode = row.at_xpath('td[@class="statusXcode"]').text.strip.split("\n")[0]
	      p.download_url = row.at_xpath('td[@class="action"]/a/@href')
	      profiles << p
	    end
	    profiles
	  end  

	  def read_all_profiles()
	    all_profiles = []
	    @profile_urls.each { |type, url|
	      info("Fetching #{type} profiles")
	      page = load_page_or_login(url)
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
	      # :displayId, :type, :name, :exp_date, :profiles, :status, :download_url
	      c.download_url = last_elt.at_xpath('a/@href')
	      c.displayId = c.download_url.to_s.split("certDisplayId=")[1]
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
	      # :displayId, :type, :name, :exp_date, :profiles, :status, :download_url
	      c.download_url = last_elt.at_xpath('a/@href')
	      c.displayId = c.download_url.to_s.split("certDisplayId=")[1]
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

	  def read_all_certificates()
	    all_certs = []
	    info("Fetching development certificates")
	    page = load_page_or_login(@certificate_urls[:development])    
	    all_certs.concat(read_certificates_development(page, :development))
	    info("Fetching distribution certificates")
	    page = load_page_or_login(@certificate_urls[:distribution])    
	    all_certs.concat(read_certificates_distribution(page, :distribution))
	    all_certs
	  end

	  def read_devices()
	    info("Fetching devices")
	    page = load_page_or_login(@devices_url)
	  
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

	  def fetch_site_data()
	    site = {}
	    @apple_cert_file = "#{@dumpDir}/AppleIncRootCertificate.cer"
	    @agent.get(@apple_cert_url).save(@apple_cert_file) if not File.exists?(@apple_cert_file)

	    site[:devices] = read_devices()
	    site[:profiles] = read_all_profiles()
	    site[:certificates] = read_all_certificates()

	    download_profiles(site[:profiles], @dumpDir, @profileFileName)
	    download_certificates(site[:certificates], @dumpDir)
	    
	    site
	  end
	  
	  # Return the uuid of the specified mobile provisioning file.
	  def pp_uuid(ppfile)
	  	ProvisioningProfile.new(ppfile, @apple_cert_file)["UUID"]
	  end
	  
	  def download_profiles(profiles, dumpDir, profileFileName)
	    profiles.each do |p|
	      if p.statusXcode != "Active"
	        info("Profile '#{p.name}' has status '#{p.statusXcode}'. Download skipped.")
	        next
	      end
	      filename = "#{dumpDir}/#{p.blob_id}.mobileprovision"
	      info("Downloading profile #{p.blob_id} '#{p.name}'.")
	      @agent.get(p.download_url).save(filename)
	      uuid = pp_uuid(filename)
	      p.uuid = uuid
	      if profileFileName == :uuid
	        basename = p.uuid
	      else
	        basename = p.name
	      end
	      newfilename = "#{dumpDir}/#{basename}.mobileprovision"
	      File.rename(filename, "#{newfilename}")
	      info("Saved profile #{p.uuid} '#{p.name}' in #{newfilename}.")
	    end
	  end

	  def download_certificates(certs, dumpDir)
	    certs.each do |c|
	      filename = "#{dumpDir}/#{c.displayId}.cer"
	      info("Downloading cert #{c.displayId} -#{c.type}- '#{c.name}'.")
	      @agent.get(c.download_url).save(filename)
	      info("Saved cert #{c.displayId} '#{c.name}' in #{filename}.")
	    end
	  end
	end

	class ProvisioningProfile
	  def initialize(file, certificate=nil)
		@profile = File.read(file)
		@p7 = OpenSSL::PKCS7.new(@profile)
  		@store = OpenSSL::X509::Store.new
  		if certificate != nil
		    #curl http://www.apple.com/appleca/AppleIncRootCertificate.cer -o AppleIncRootCertificate.cer
    		cert = OpenSSL::X509::Certificate.new(File.read(certificate))
    		@store.add_cert(cert)
    		@verification = @p7.verify([cert], @store)
		else
    		@p7.verify([], @store)
    		@verification = false
  		end

		@text = @p7.data
	  end

	  def dump
		  puts("Type:                  #{@p7.type}")
		  puts("Verification:          #{@verification}")
		  if @verification
			  puts("Signers:               #{@p7.signers.size}")
			  @p7.signers.each do |signer|
			    puts("SignerInfo.Issuer:     #{signer.name}")
			    puts("SignerInfo.Serial:     #{signer.serial}")
			    puts("SignerInfo.SignedTime: #{signer.signed_time}")
			  end
		  puts("Recipients:            #{@p7.recipients.size}")
		  @p7.recipients.each do |recipient|
		    puts("RecipientInfo.EncKey:  #{recipient.enc_key}")
		    puts("RecipientInfo.issuer:  #{recipient.issuer}")
		    puts("RecipientInfo.serial:  #{recipient.serial}")
		  end
		  puts("Certificates:          #{@p7.certificates.size}")
		  @p7.certificates.each do |certificate|
		    puts certificate.to_text
		  end
			end
		end

		def [](option)
			text = @text
		  	if (option)
		    	r = Plist::parse_xml(text)
	    		text = r[option]
	  		end
	  		text
		end

		def text
			@text
		end
	end
  end
end
