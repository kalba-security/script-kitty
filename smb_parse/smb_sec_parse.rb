#!/usr/bin/env ruby

require 'optparse'

def help(logo,print_help=false)
  options = {'scheme' => 'smbsecparsed'}
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [file1] [file2] [file3] ... [filex]"
    opts.on("-h", "--help", "Display this menu and exit") do
      print_help = true
    end
    opts.on("-d", "--dir     OUTPUT_DIRECTORY", "Directory to store results.\n\t\t\t\t     If it doesn't exist, Showdan creates it.") do |directory|
      options['directory'] = directory;
    end
    opts.on("-s", "--scheme  NAMING_SCHEME", "Naming scheme for the output file(s).\n\t\t\t\t     Default: 'smbsecparsed_[inputfile].'\n\t\t\t\t     For multiple input files, the name of\n\t\t\t\t     each file is appended to the scheme.") do |scheme|
      options['scheme'] = scheme;
    end
  end
  parser.parse!

  if print_help == true
    logo.each { |i| puts i }
    puts parser
    puts "\n  Example: #{$0} nmap_smb_results1.txt nmap_smb_results2.txt"
    puts "  Example: #{$0} scan1.txt -o results"
    exit
  end
  options
end

if $0 == __FILE__
  warning = "[" + "\033[01;33m" + "!" + "\033[00m" + "]"
  info = "[" + "\033[01;34m" + "*" + "\033[00m" + "]"
  success = "[" + "\033[01;32m" + "+" + "\033[00m" + "]"
  failure = "[" + "\033[01;31m" + "-" + "\033[00m" + "]"

  banner = "*" * 70 + "\n\t\t\033[01;32mSMB-SEC-PARSE v1.0\033[00m - \033[01;34mErik Wynter (@wyntererik)\033[00m\n" + "*" * 70
  descr1 = "\nEasily parse the results of Nmap's 'smb-security-mode' NSE script."
  descr2 = "Compatible with .nmap files or copy-pasted 'smb-security-mode' output."
  logo = [banner,descr1,descr2] 

  if ARGV.length() == 0
    puts "#{warning} Please provide at least one file to parse."
    puts "#{info} Loading help menu:"
    help(logo,true)
  end

  options = help(logo) 
  scheme = options['scheme']

  if options['directory']
      directory = options['directory']
      system("[ -d #{directory} ]") 
      unless $?.exitstatus == 0
        system("mkdir #{directory}")
        unless $?.exitstatus == 0
          puts("#{failure} Failed to create #{directory} to store the results.")
          puts("#{warning} Quitting!")
          exit
        end
        puts("#{info}Created output directory '#{directory}'")
      end
    else
      directory = "."
    end
    directory += "/" if directory[-1] != "/"

  ARGV.each do |file| 
    results = {}
    begin
      hosts_info = File.open(file).read.split("report for ") #split file contents into chunkcs for each host
      hosts_info.shift #remove nmap initiation info
      unless hosts_info.to_s.include? "Anonymous access: READ"
        puts "#{failure} #{file}: Did not find shares allowing null session authentication."
        next
      end
      hosts_info.each do |data|
        if data.include? "disabled (dangerous"
          ip = data.split("\n")[0]
          lines = data.split("\n")
          lines.each do |l|
            if (l.include? "message_signing") && (l.include? "disabled (dangerous")
              l = l.split(" ").drop(1).join(" ")
              results[ip] = l
            end
          end
        end
      end
      puts "#{success} #{file}: SMB message signing is disabled on #{results.length()} systems."
      if ARGV.length() == 1
        if scheme == "smbsecparsed"
          scheme += ".txt"
        end
        out_file = directory + scheme
      else
        if file.include? "/"
          f_scheme = file.split("/")
          f_scheme = f_scheme[f_scheme.length() -1]
        else
          f_scheme = file
        end
        scheme = scheme.delete_suffix('_') #remove prevent getting "_" twice in a row at the end of scheme
        out_file = directory + scheme + "_" + f_scheme
      end
      puts "#{info} Writing results to '#{out_file}'.\n"
      puts "Affected hosts:"
      hosts = results.keys
      hosts = hosts.each_slice(5).to_a
      hosts.each { |ip| puts ip.join("   ")}
      File.open(out_file, "w") {
        |f| results.each do |ip,evidence|
          puts "-" *62 + "\n|IP: #{ip}"
          f.write("-" *62 + "\n|IP: #{ip}\n")
          puts "|-#{evidence}"
          f.write("|-#{evidence}\n")
        end
        puts "-" *62
        f.write("-" *62 + "\n")
      }
    end
  rescue
    puts "#{error} Unable to parse '#{file}'."
    puts "#{warning} Please provide only .nmap files or files containing copy-pasted Nmap output.\n\n"
    next
  end
end