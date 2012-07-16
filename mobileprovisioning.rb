#!/usr/bin/ruby
require "rubygems"
require "plist"
require "openssl"
require "optparse"

def ensure_file_specified_and_exists(name, file)
  raise OptionParser::MissingArgument, name if file.nil?
  raise OptionParser::InvalidArgument, "'#{file}' #{name} file doesn't exists" if not File.exists?(file)
end

def parse_command_line(args)
  options = {}

  opts = OptionParser.new { |opts|
    opts.banner = "Usage: #{File.basename($0)} profileFile options"
    opts.separator("Options:")
    
    opts.on( '-d', '--dump [KEY]', 'Dump a particular KEY or the full XML.') do |key|
      options[:dump] = true
      options[:dumpKey] = key
    end
    opts.on( '-t', '--type', 'Prints the type of the profile (distribution or development).') do |key|
      options[:type] = true
    end
    opts.on( '-o', '--output FILE', 'Write output to FILE. Default is standard output.') do |output|
      options[:output] = output
    end
    opts.on('-c', '--certificate CERTIFICATE', 'Use CERTIFICATE to verify profile.') do |certificate|
      options[:certificate] = certificate
    end
    options[:verbose] = false
    opts.on('-v', '--verbose', "Show the profile's type, verification, signers, recipients and certificates.") do
      options[:verbose] = true
    end
    opts.on_tail( '-h', '--help', 'Display this screen.' ) do
      puts opts
      exit
    end
  }
  
  if (args.empty?)
    puts opts
    exit
  end
  
  begin 
    opts.parse!(args)
  rescue OptionParser::ParseError => e
    puts "Found #{e}"
    puts opts
    exit 1
  end

  options[:profile] = args[0]
  ensure_file_specified_and_exists("profile", options[:profile])
  
  options
end

def dump(text, file)
  if (file)
    File.open(file, 'w') { |f| f.write(text) }
  else
    puts text
  end
end

def dumpProfile(xml, options)
  text = xml
  if text.nil?
    puts "The profile content is nil. Maybe the verification failed? Try -v."
  else
    if (options[:dumpKey])
      r = Plist::parse_xml(xml)  
      text = r[options[:dumpKey]]
    end
    dump(text, options[:output])
  end
end

def dumpProfileType(xml, options)
  r = Plist::parse_xml(xml)
  # http://stackoverflow.com/questions/1003066/what-does-get-task-allow-do-in-xcode
  get_task_allow = r["Entitlements"]["get-task-allow"]
  type = get_task_allow ? "development" : "distribution"
  dump(type, options[:output])
end

def main()
  options = parse_command_line(ARGV)
  
  profile = File.read(options[:profile])
  p7 = OpenSSL::PKCS7.new(profile)
  
  store = OpenSSL::X509::Store.new
  
  if options[:certificate] != nil
    #curl http://www.apple.com/appleca/AppleIncRootCertificate.cer -o AppleIncRootCertificate.cer
    cert = OpenSSL::X509::Certificate.new(File.read(options[:certificate]))
    store.add_cert(cert)
    verification = p7.verify([cert], store)
  else
    p7.verify([], store)
    verification = 'false'
  end

  if options[:verbose]
    puts("Type:                  #{p7.type}")
    puts("Verification:          #{verification}")
    puts("Signers:               #{p7.signers.size}")
    p7.signers.each do |signer|
      puts("SignerInfo.Issuer:     #{signer.name}")
      puts("SignerInfo.Serial:     #{signer.serial}")
      puts("SignerInfo.SignedTime: #{signer.signed_time}")
    end
    puts("Recipients:            #{p7.recipients.size}")
    p7.recipients.each do |recipient|
      puts("RecipientInfo.EncKey:  #{recipient.enc_key}")
      puts("RecipientInfo.issuer:  #{recipient.issuer}")
      puts("RecipientInfo.serial:  #{recipient.serial}")
    end
    puts("Certificates:          #{p7.certificates.size}")
    p7.certificates.each do |certificate|
      puts certificate.to_text
    end
  end
  
  text = p7.data

  if (options[:dump])
    dumpProfile(text, options)
  elsif (options[:type])
    dumpProfileType(text, options)
  end
end

main()
