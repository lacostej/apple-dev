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
	  attr_accessor :uuid, :blob_id, :type, :name, :appid, :status_xcode, :download_url
	  def to_json(*a)
	    {
	      'uuid' => uuid,
	      'type' => type,
	      'name' => name,
	      'appid' => appid,
	      'status_xcode' => status_xcode
	#      'blob_id' => blob_id,      
	#      'download_url' => download_url,
	    }.to_json(*a)
	  end
	end

	class Certificate
	  attr_accessor :display_id, :type, :name, :exp_date, :profile, :status, :download_url
	  def to_json(*a)
	    {
	      'display_id' => display_id,
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
	    
	    @apple_cert_url = 'http://www.apple.com/appleca/AppleIncRootCertificate.cer'
	    
	    @profile_urls = {}
	    @profile_urls[:development] = 'https://developer.apple.com/account/ios/profile/profileList.action?type=limited'
	    @profile_urls[:distribution] = 'https://developer.apple.com/account/ios/profile/profileList.action?type=production'

	    @certificate_urls = {}
	    @certificate_urls[:development] = 'https://developer.apple.com/account/ios/certificate/certificateList.action?type=development'
	    @certificate_urls[:distribution] = 'https://developer.apple.com/account/ios/certificate/certificateList.action?type=distribution'

	    @devices_url = 'https://developer.apple.com/account/ios/device/deviceList.action'

	    @login = options[:login]
	    @passwd = options[:passwd]
	    @login = options[:login]
	    @teamid = options[:teamid]
	    @teamname = options[:teamname]
	    @dump_dir = options[:dump_dir]
		@profile_file_name = options[:profile_file_name]
	  end

	  def load_page_or_login(url)
	    debug "Loading #{url}"
	    page = @agent.get(url)
	    debug page.title

	    login_if_required(page, url)
	  end

	  def login_if_required (page, url)
	    # Log in to Apple Developer portal if we're presented with a login form.
	    form = page.forms.first if page.uri.to_s.include?('login')
	    if form
	      info "Logging in with Apple ID '#{@login}'."
	      form.field_with(type: 'text').value = @login
	      form.field_with(type: 'password').value = @passwd
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
      	  	info 'ERROR select team page format has changed. Contact us'
      	  end
	    else
	  	  debug 'No team choice detected'
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
			debug 'team: ' + name + ' ' + teamid + ' ' + idx.to_s
			team_option = rb if team_option.nil? and is_prefered_team(name, teamid, idx)
		}
		raise "ERROR: couldn't find an option that matches your criteria" if team_option.nil?
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
	  	profile_data_url = page.body.match(/var profileDataURL = "(.*)";/).captures[0]
	  	profile_list_url = page.body.match(/var profileListUrl = "(.*)";/).captures[0]

	  	page, json = post_paginate profile_data_url, "status"

	    profiles = []
	    # Format each row as name,udid
	    json['provisioningProfiles'].each do |prof|
	      p = Profile.new()
	      provisioning_profile_id = prof['provisioningProfileId']
	      p.blob_id = provisioning_profile_id
	      p.type = type
	      p.name = prof['name']
				# This key is obsolete, so I will use nil for now
	      # p.appid = prof['appId']['name']
	      p.appid = nil
	      p.status_xcode = prof['status']
	      p.download_url = "https://developer.apple.com/account/ios/profile/profileContentDownload.action?displayId=#{provisioning_profile_id}"
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
	  	certificate_data_url = page.body.match(/var certificateDataURL = "(.*)";/).captures[0]
	  	certificate_request_types = page.body.match(/var certificateRequestTypes = "(.*)";/).captures[0]
	  	certificate_statuses = page.body.match(/var certificateStatuses = "(.*)";/).captures[0]
	  	certificate_data_url += certificate_request_types + certificate_statuses
	  	certificate_list_url = page.body.match(/var certificateListUrl = "(.*)";/).captures[0]
		#var developerIDTypes = ['...', '...'];

		#info(certificate_data_url)
		page, json = post_paginate certificate_data_url, "certRequestStatusCode"

	    certs = []
	    json['certRequests'].each do |cert|
	      can_download = cert['canDownload']
	      next unless can_download
	      c = Certificate.new()
	      display_id = cert['certificateId']
	      type_id = cert['certificateTypeDisplayId']

	      # :displayId, :type, :name, :exp_date, :profiles, :status, :download_url
	      c.download_url = "https://developer.apple.com/account/ios/certificate/certificateContentDownload.action?displayId=#{display_id}&type=#{type_id}"
	      c.display_id = display_id
	      c.type = type
	      c.name = cert['name']
	      c.exp_date = cert['expirationDate']
	      # unsure if one certificate can be mapped to several profiles
	      c.profile = 'N/A'
	      c.status = cert['statusString']
	      certs << c
	    end
	    certs
	  end
	  
	  def read_all_certificates()
	    all_certs = []
	    info('Fetching development certificates')
	    page = load_page_or_login(@certificate_urls[:development])
	    all_certs.concat(read_certificates(page, :development))
	    info('Fetching distribution certificates')
	    page = load_page_or_login(@certificate_urls[:distribution])    
	    all_certs.concat(read_certificates(page, :distribution))
	    all_certs
	  end

	  def read_devices()
	    info('Fetching devices')
	    page = load_page_or_login(@devices_url)

	  	device_data_url = page.body.match(/var deviceDataURL = "(.*)";/).captures[0]
	  	device_list_url = page.body.match(/var deviceListUrl = "(.*)"[;,]/).captures[0]
	  	device_enable_url = page.body.match(/var deviceEnableUrl = "(.*)";/).captures[0]
	  
		#search=&nd=1429706180729&pageSize=500&pageNumber=1&sidx=status&sort=status%253dasc
		page, json = post_paginate device_data_url, "status"

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

	  def post_paginate(url, column)
		debug "paginating #{url}"
	    page = @agent.post(url, {
	     "pageSize" => 500,
	     "pageNumber" => 1,
	     "sort" => "#{column}%3dasc"
		})
	    debug page.body
	    #@agent.log.info(page.body)
	    json = JSON.parse(page.body)
	    checkJson json
	    return page, json
	  end

	  def checkJson(json)
	    if (json['resultCode'] != 0)
	    	raise "Failed to get results '#{json['resultString']}' from '#{json['requestUrl']}'"
	    end
	  end

	  def fetch_site_data()
	    site = {}
	    @apple_cert_file = "#{@dump_dir}/AppleIncRootCertificate.cer"
	    @agent.get(@apple_cert_url).save(@apple_cert_file) if not File.exists?(@apple_cert_file)

	    site[:devices] = read_devices()
	    site[:profiles] = read_all_profiles()
	    site[:certificates] = read_all_certificates()

	    download_profiles(site[:profiles], @dump_dir, @profile_file_name)
	    download_certificates(site[:certificates], @dump_dir)
	    
	    site
	  end
	  
	  # Return the uuid of the specified mobile provisioning file.
	  def pp_uuid(ppfile)
	  	ProvisioningProfile.new(ppfile, @apple_cert_file)['UUID']
	  end
	  
	  def download_profiles(profiles, dump_dir, profile_file_name)
	  	if profiles.nil?
	  		info('no profiles found')
	  		return
	  	end
	    profiles.each do |p|
	      if p.status_xcode != 'Active'
	        info("Profile '#{p.name}' has status '#{p.status_xcode}'. Download skipped.")
	        next
	      end
	      filename = "#{dump_dir}/#{p.blob_id}.mobileprovision"
	      info("Downloading profile #{p.blob_id} '#{p.name}'.")
	      @agent.get(p.download_url).save(filename)
	      uuid = pp_uuid(filename)
	      p.uuid = uuid
	      if profile_file_name == :uuid
	        basename = p.uuid
	      else
	        basename = p.name
	      end
	      newfilename = "#{dump_dir}/#{basename}.mobileprovision"
	      File.rename(filename, "#{newfilename}")
	      info("Saved profile #{p.uuid} '#{p.name}' in #{newfilename}.")
	    end
	  end

	  def download_certificates(certs, dump_dir)
	    certs.each do |c|
	      filename = "#{dump_dir}/#{c.display_id}.cer"
	      info("Downloading cert #{c.display_id} -#{c.type}- '#{c.name}'.")
	      @agent.get(c.download_url).save(filename)
	      info("Saved cert #{c.display_id} '#{c.name}' in #{filename}.")
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
		  	if option
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
