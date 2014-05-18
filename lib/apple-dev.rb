#require "apple-dev/version"
require 'mechanize'
require 'json'
require 'plist'
#require 'logger' # Use this to log mechanize.

def debug(s)
	#puts "DEBUG: #{s}"
end

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
	  attr_accessor :id, :udid, :name
	  def to_json(*a)
	    {
	      'id' => id,
	      'udid' => udid,
	      'name' => name
	    }.to_json(*a)
	  end
	end


	class IOSProvisioningPortal
	  def initialize(options)
	    @agent = Mechanize.new
	    @agent.follow_meta_refresh = true
	    @agent.pluggable_parser.default = Mechanize::File
	    #@agent.log = Logger.new('mechanize.log')
	    
	    # Set proxy if environment variable 'https_proxy' is set.
	    proxy_regex = /:\/\/(.[^:]*):(\d*)/
	    if ENV['https_proxy'] != nil && ENV['https_proxy'].match(proxy_regex) 
	      @agent.set_proxy(Regexp.last_match(1), Regexp.last_match(2))
	    end
	    
	    @apple_cert_url = "http://www.apple.com/appleca/AppleIncRootCertificate.cer"
	    
	    @profile_urls = {}
	    @profile_urls[:development] = "https://developer.apple.com/account/ios/profile/profileList.action?type=limited"
	    @profile_urls[:distribution] = "https://developer.apple.com/account/ios/profile/profileList.action?type=production"

	    @certificate_urls = {}
	    @certificate_urls[:development] = "https://developer.apple.com/account/ios/certificate/certificateList.action?type=development"
	    @certificate_urls[:distribution] = "https://developer.apple.com/account/ios/certificate/certificateList.action?type=distribution"

	    @devices_url = "https://developer.apple.com/account/ios/device/deviceList.action"

	    @login = options[:login]
	    @passwd = options[:passwd]
	    @login = options[:login]
	    @teamid = options[:teamid]
	    @teamname = options[:teamname]
	    @dumpDir = options[:dumpDir]
	  end

	  def load_page_or_login(url)
	    debug "Loading #{url}"
	    page = @agent.get(url)
	    debug page.title

	    # Log in to Apple Developer portal if we're presented with a login form.
	    form = page.form_with(:name => 'form2')
	    if form
	      info "Logging in with Apple ID '#{@login}'."
	      form['appleId'] = @login
	      form['accountPassword'] = @passwd
	      page = form.click_button
	      debug "Loading #{url}"
	      #page = @agent.get(url)
	      #puts page.body
	      error=page.parser.xpath('//span[@class="dserror"]')
	      if error and !error.empty?
	      	msg = "ERROR: #{error.text}"
	      	raise msg
	      end
	      debug page.title
  	      page = select_team(page, url)
	    end
	    page
	  end

      # Select a team if you belong to multiple teams.
	  def select_team(page, url)
	    form = page.form_with(:name => 'saveTeamSelection')
	    if form
	      page = select_team_radiobutton(form, page)
      	  if page.nil?
      	  	page = select_team_dropbox(form, page)
	      end
      	  if page.nil?
      	  	info "ERROR select team page format has changed. Contact us"
      	  end
	    else
	  	  debug "No team choice detected"
	    end
  		page = @agent.get(url)
	  end

	  def is_prefered_team(teamname, teamvalue, idx)
	    if @teamid.nil? || @teamid == ''
	      if @teamname.nil? || @teamname == ''
	      	prefered = idx == 0
	      else
	        prefered = teamname == @teamname
	      end
	    else
	        prefered = teamvalue == @teamid
	    end
	    prefered
	  end

	  def select_team_radiobutton(form, page)
		team_option=nil
		form.radiobuttons.each_with_index {|rb, idx| 
			rbid=rb['id']
			teamid=rb['value']   
			name=page.parser.xpath('//label[@class="label-primary" and @for="' + rbid + '"]').text.strip
			debug "team: " + name + " " + teamid + " " + idx.to_s
			team_option = rb if team_option.nil? and is_prefered_team(name, teamid, idx)
		}
		if team_option.nil?
			raise "ERROR: couldn't find an option that matches your criteria"
		end
		team_option.check
  		btn = form.button_with(:name => 'action:saveTeamSelection!save')
  		form.click_button(btn)
	  end

	  def select_team_dropbox(form, page)
	      team_list = form.field_with(:name => 'memberDisplayId')
	      return nil if (team_list.nil?)

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
	  end

	  def read_profiles(page, type)
	  	profileDataURL = page.body.match(/var profileDataURL = "(.*)";/).captures[0]
	  	profileListUrl = page.body.match(/var profileListUrl = "(.*)";/).captures[0]

	    page = @agent.post(profileDataURL)
	    json = JSON.parse(page.body)

	    profiles = []
	    # Format each row as name,udid
	    json['provisioningProfiles'].each do |prof|
	      p = Profile.new()
	      provisioningProfileId = prof['provisioningProfileId']
	      p.blob_id = provisioningProfileId
	      p.type = type
	      p.name = prof['name']
	      p.appid = prof['appId']['name']
	      p.statusXcode = prof['status']
	      p.download_url = "https://developer.apple.com/account/ios/profile/profileContentDownload.action?displayId=#{provisioningProfileId}"
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

	  def read_certificates(page, type)
	  	certificateDataURL = page.body.match(/var certificateDataURL = "(.*)";/).captures[0]
	  	certificateRequestTypes = page.body.match(/var certificateRequestTypes = "(.*)";/).captures[0]
	  	certificateStatuses = page.body.match(/var certificateStatuses = "(.*)";/).captures[0]
	  	certificateDataURL += certificateRequestTypes + certificateStatuses
	  	certificateListUrl = page.body.match(/var certificateListUrl = "(.*)";/).captures[0]
		#var developerIDTypes = ['...', '...'];

		#info(certificateDataURL)
	    page = @agent.post(certificateDataURL)
	    json = JSON.parse(page.body)

	    certs = []
	    json['certRequests'].each do |cert|
	      canDownload = cert['canDownload']
	      if (canDownload)
	        c = Certificate.new()
	        displayId = cert['certificateId']
	        typeId = cert['certificateTypeDisplayId']

	        # :displayId, :type, :name, :exp_date, :profiles, :status, :download_url
	        c.download_url = "https://developer.apple.com/account/ios/certificate/certificateContentDownload.action?displayId=#{displayId}&type=#{typeId}"
	        c.displayId = displayId
	        c.type = type
	        c.name = cert['name']
	        c.exp_date = cert['expirationDate']
	        # unsure if one certificate can be mapped to several profiles
	        c.profile = 'N/A'
	        c.status = cert['statusString']
	        certs << c
	      end
	    end
	    certs
	  end
	  
	  def read_all_certificates()
	    all_certs = []
	    info("Fetching development certificates")
	    page = load_page_or_login(@certificate_urls[:development])    
	    all_certs.concat(read_certificates(page, :development))
	    info("Fetching distribution certificates")
	    page = load_page_or_login(@certificate_urls[:distribution])    
	    all_certs.concat(read_certificates(page, :distribution))
	    all_certs
	  end

	  def read_devices()
	    info("Fetching devices")
	    page = load_page_or_login(@devices_url)

	  	deviceDataURL = page.body.match(/var deviceDataURL = "(.*)";/).captures[0]
	  	deviceListUrl = page.body.match(/var deviceListUrl = "(.*)";/).captures[0]
	  	deviceEnableUrl = page.body.match(/var deviceEnableUrl = "(.*)";/).captures[0]
	  
		debug deviceDataURL
	    page = @agent.post(deviceDataURL)
	    json = JSON.parse(page.body)

	    devices = []
	    json['devices'].each do |device|
	      d = Device.new()
	      d.id = device['deviceId']
	      d.name = device['name']
	      d.udid = device['deviceNumber']
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
	  	if profiles.nil?
	  		info("no profiles found")
	  		return
	  	end
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
