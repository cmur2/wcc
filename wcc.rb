#!/usr/bin/ruby -KuW0

require 'digest/md5'
require 'uri'
require 'optparse'
require 'singleton'
require 'net/http'
require 'net/smtp'
require 'pathname'
require 'logger'
require 'iconv'

class Conf
	include Singleton
	
	def initialize 
		@options = {
			:verbose => false, 
			:debug => false, 
			:quiet => false, 
			:dir => '/var/tmp/wcc',
			:simulate => false,
			:clean => false,
			:tag => 'web change checker2'
		}
	
		optparse = OptionParser.new do|opts|
			opts.banner = "Usage: ruby wcc.rb [options] [config-file]"
			opts.on('-q', '--quiet', 'Show only errors') do @options[:quiet] = true end
			opts.on('-v', '--verbose', 'Output more information') do @options[:verbose] = true end
			opts.on('-d', '--debug', 'Enable debug mode') do @options[:debug] = true end
			opts.on('-o', '--dir DIR', 'Save required files to DIR') do |dir| @options[:dir] = dir end
			opts.on('-s', '--simulate', 'Check for update but does not save any data') do @options[:simulate] = true end
			opts.on('-c', '--clean', 'Removes all hash and diff files') do @options[:clean] = true end
			opts.on('-t', '--tag TAG', 'Sets TAG used in output') do |t| @options[:tag] = t end
			opts.on('-n', '--no-mails', 'Does not send any emails') do @options[:nomails] = true end
			opts.on('-f', '--from MAIL', 'Set sender mail address') do |m| @options[:from] = m end
			opts.on('-h', '--help', 'Display this screen') do
				puts opts
				exit
			end
		end
		optparse.parse!
		
		if @options[:from].to_s.empty?
			$logger.fatal "No sender mail address given! See help."
			exit 1
		end
		
		$logger.warn "No config file given, using default 'conf' file" if ARGV.length == 0

		@options[:conf_file] = ARGV[0] || 'conf'
		
		if !File.exists?(@options[:conf_file])
			$logger.fatal "Config file '#{@options[:conf_file]}' does not exist!"
			exit 1
		end
		
		# create dir for hash files
		Dir.mkdir(@options[:dir]) unless File.directory?(@options[:dir])
		
		if(@options[:clean])
			$logger.warn "Cleanup hash and diff files"
			Dir.foreach(@options[:dir]) do |f|
				File.delete(@options[:dir] + "/" + f) if f =~ /^.*\.(md5|site)$/
			end
		end
	end
	
	def options; @options end
	
	def self.sites
		return @sites unless @sites.nil?
		
		conf_file = Conf.instance.options[:conf_file] if conf_file.nil?
		@sites = []
		
		$logger.debug "Load sites from '#{conf_file}'"
		
		File.open(conf_file).each do |line|
			# regex to match required config lines; all other lines are ignored
			if line =~ /^[^#]*?;.*?[;.*?]+;?/
				conf_line = line.strip.split(';')
				@sites << Site.new(conf_line[0], conf_line[1], conf_line[2, conf_line.length])
			end
		end
		
		$logger.debug @sites.length.to_s + (@sites.length == 1 ? ' site' : ' sites') + " loaded\n" +
			@sites.map { |s| "  " + s.uri.host.to_s + "\n    url: " +
			s.uri.to_s + "\n    id: " + s.id }.join("\n")
		@sites
	end
	
	def self.file(path = nil) File.join(self.dir, path) end
	
	# aliases for Conf.instance.options[:option]
	def self.dir; Conf.instance.options[:dir] end
	def self.debug?; Conf.instance.options[:debug] end
	def self.verbose?; (Conf.instance.options[:verbose] and !self.quiet?) or self.debug? end
	def self.quiet?; Conf.instance.options[:quiet] and !self.debug? end
	def self.simulate?; Conf.instance.options[:simulate] end
	def self.tag; Conf.instance.options[:tag] end
	def self.send_mails?; !Conf.instance.options[:nomails] end
	def self.from_mail; Conf.instance.options[:from] end
end

class Site
	attr_accessor :hash, :content
	
	def initialize(url, striphtml, emails)
		@uri = URI.parse(url)
		@striphtml = !!striphtml
		@emails = emails.is_a?(Array) ? emails : [emails]
		@id = Digest::MD5.hexdigest(url.to_s)[0...8]
		load_hash
	end
	
	def uri; @uri end
	def striphtml?; @striphtml end
	def emails; @emails end
	def id; @id end
	
	def to_s; "%s;%s;%s" % [@uri.to_s, (@striphtml ? 'yes' : 'no'), @emails.join(';')] end
	
	def hash; @hash.to_s end
	def content; load_content if @content.nil?; @content end
	
	def load_hash
		file = Conf.file(self.id + ".md5")
		if File.exists?(file)
			$logger.debug "Load hash from file '#{file}'"
			File.open(file, "r") { |f| @hash = f.gets; break }
		else
			$logger.info "Site #{uri.host} was never checked before."
		end
	end
	
	def load_content
		file = Conf.file(self.id + ".site")
		if File.exists?(file)
			$logger.debug "Read site content from file '#{file}'"
			File.open(file, "r") { |f| @content = f.read }
		end
	end
	
	def hash=(hash)
		@hash = hash
		return if Conf.simulate?
		file = Conf.file(self.id + ".md5")
		$logger.debug "Save new site hash to file '#{file}'"
		File.open(file, "w") { |f| f.write(@hash) }
	end
	
	def content=(content)
		@content = content
		return if Conf.simulate?
		file = Conf.file(self.id + ".site")
		$logger.debug "Save new site content to file '#{file}'"
		File.open(file, "w") { |f| f.write(@content) }
	end
end

def stripHTML(html)
	# html <tag> eater
	new = html.gsub(/<[^>]*>/, ' ')
	
	# TODO: entity convesion
	
	return new
end

def detectEncoding(html)
	enc = "utf-8"
	re = Regexp.new('<meta.*charset=([a-zA-Z0-9-]*).*', Regexp::IGNORECASE)
	match = re.match(html)
	
	if match != nil
		enc = match[1].downcase()
	end
	return enc
end

def checkForUpdate(site)
	$logger.info "Requesting '#{site.uri.to_s}'"
	begin
		res = Net::HTTP.get_response(site.uri)
	rescue
		$logger.error "Cannot connect to '#{site.uri.to_s}': #{$!.to_s}"
		return false
	end
	if not res.kind_of?(Net::HTTPOK)
		$logger.warn "Site #{site.uri.to_s} returned #{res.code} code, skipping it."
		return false
	end
	$logger.info "#{res.code} response received"
	
	new_site = res.body
	new_hash = Digest::MD5.hexdigest(res.body)
	enc = detectEncoding(new_site)
	
	$logger.info "Encoding is '#{enc}'"
	
	# convert to utf-8
	new_site = Iconv.conv('utf-8', enc, new_site)
	
	$logger.debug "Compare hashes\n  old: #{site.hash.to_s}\n  new: #{new_hash.to_s}"
	return false if new_hash == site.hash
	
	# save old site to tmp file
	old_site_file = "/tmp/wcc-#{site.id}.site"
	File.open(old_site_file, "w") { |f| f.write(site.content) }
	
	# do update
	site.hash, site.content = new_hash, new_site
	
	# diff between OLD and NEW
	old_label = "OLD (%s)" % File.mtime(Conf.file(site.id + ".md5")).to_s
	new_label = "NEW (%s)" % Time.now.to_s
	diff = %x{diff -U 1 --label "#{old_label}" --label "#{new_label}" #{old_site_file} #{Conf.file(site.id + ".site")}}
	
	if site.striphtml?
#		diff = stripHTML(diff)
	end
	
	Net::SMTP.start('localhost', 25) do |smtp|
		site.emails.each do |mail|
			msg  = "From: #{Conf.from_mail}\n"
			msg += "To: #{mail}\n"
			msg += "Subject: [#{Conf.tag}] #{site.uri.host} changed\n"
			msg += "\n"
			msg += "Change at #{site.uri.to_s} - diff follows:\n\n"
			msg += diff
			
			smtp.send_message msg, Conf.from_mail, mail
		end
	end if Conf.send_mails?
	
	true
end

class MyFormatter
	def call(severity, time, progname, msg)
		#"%s %5s: %s" % [time.strftime('%H:%M:%S'), severity, msg.to_s]
		"%s: %s\n" % [severity, msg.to_s]
	end
end

# create global logger
$logger = Logger.new(STDOUT)
$logger.formatter = MyFormatter.new
$logger.progname = Conf.tag

# latest flag overrides everything
$logger.level = Logger::WARN
$logger.level = Logger::ERROR if Conf.quiet?
$logger.level = Logger::INFO if Conf.verbose?
$logger.level = Logger::DEBUG if Conf.debug?

Conf.sites.each do |site|
	if checkForUpdate(site)
		$logger.warn "#{site.uri.host.to_s} has an update!"
	else
		$logger.info "#{site.uri.host.to_s} is unchanged"
	end
end
