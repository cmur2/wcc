
require 'base64'
require 'digest/md5'
require 'iconv'
require 'logger'
require 'net/http'
require 'net/https'
require 'net/smtp'
require 'optparse'
require 'ostruct'
require 'pathname'
require 'singleton'
require 'tempfile'
require 'uri'
require 'yaml'

# ruby gem dependencies
require 'htmlentities'

# wcc
require 'wcc/filter'
require 'wcc/mail'
require 'wcc/site'

class String
	# Remove all HTML tags with at least one character name and
	# decode all HTML entities into utf-8 characters.
	#
	# @return [String] stripped string
	def strip_html
		HTMLEntities.new.decode(self.gsub(/<[^>]+>/, ' '))
	end
end

module WCC

	DIFF_TIME_FMT = '%Y-%m-%d %H:%M:%S %Z'
	
	# logging via WCC.logger.blub
	
	def self.logger
		@logger
	end
	
	def self.logger=(logger)
		@logger = logger
	end
	
	class Conf
		include Singleton
		
		# use Conf like a hash containing all options
		def [](key)
			@options[key.to_sym] || Conf.default[key.to_sym]
		end
		def []=(key, val)
			@options[key.to_sym] = val unless val.nil?
		end
		
		def self.default
			@default_conf ||= {
				:verbose => false,
				:debug => false,
				:simulate => false,
				:clean => false,
				:nomails => false,
				# when you want to use ./tmp it must be writeable
				:cache_dir => '/var/tmp/wcc',
				:tag => 'wcc',
				:syslog => false,
				:filter_dir => './filter.d',
				:mailer => 'smtp',
				:smtp_host => 'localhost',
				:smtp_port => 25
			}
		end
		
		def initialize
			@options = {}
			
			OptionParser.new do |opts|
				opts.banner =  "Usage: ruby wcc.rb [options] [config-yaml-file]"
				opts.banner += "\nOptions:\n"
				opts.on('-v', '--verbose', 'Output more information') do self[:verbose] = true end
				opts.on('-d', '--debug', 'Enable debug mode') do self[:debug] = true end
				opts.on('-o', '--cache-dir DIR', 'Save hash and diff files to DIR') do |dir| self[:cache_dir] = dir end
				opts.on('-s', '--simulate', 'Check for update but do not save hash or diff files') do self[:simulate] = true end
				opts.on('-c', '--clean', 'Remove all saved hash and diff files') do self[:clean] = true end
				opts.on('-t', '--tag TAG', 'Set TAG used in output') do |t| self[:tag] = t end
				opts.on('-n', '--no-mails', 'Do not send any emails') do self[:nomails] = true end
				opts.on('-f', '--from MAIL', 'Set From: mail address') do |m| self[:from_mail] = m end
				opts.on('--host HOST', 'Set SMTP host') do |h| self[:host] = h end
				opts.on('--port PORT', 'Set SMTP port') do |p| self[:port] = p end
				opts.on('--show-config', 'Show config after loading config file (debug purposes)') do self[:show_config] = true end
				opts.on('-h', '-?', '--help', 'Display this screen') do
					puts opts
					exit
				end
			end.parse!
			
			WCC.logger.progname = 'wcc'

			# latest flag overrides everything
			WCC.logger.level = Logger::ERROR
			WCC.logger.level = Logger::INFO if self[:verbose]
			WCC.logger.level = Logger::DEBUG if self[:debug]
			
			WCC.logger.formatter = LogFormatter.new((self[:verbose] or self[:debug]))

			# main
			WCC.logger.info "No config file given, using default 'conf.yml' file" if ARGV.length == 0

			self[:conf] = ARGV[0] || 'conf.yml'
			
			if !File.exists?(self[:conf])
				WCC.logger.fatal "Config file '#{self[:conf]}' does not exist!"
				exit 1
			end
			
			WCC.logger.debug "Load config from '#{self[:conf]}'"
			
			# may be false if file is empty
			yaml = YAML.load_file(self[:conf])
			if yaml.is_a?(Hash) and (yaml = yaml['conf']).is_a?(Hash)
				@options[:from_mail] ||= yaml['from_addr']
				@options[:cache_dir] ||= yaml['cache_dir']
				@options[:tag] ||= yaml['tag']
				@options[:syslog] ||= yaml['use_syslog']
				@options[:filter_dir] ||= yaml['filterd']
				
				if yaml['email'].is_a?(Hash)
					if yaml['email']['smtp'].is_a?(Hash)
						@options[:mailer] = 'smtp'
						@options[:smtp_host] ||= yaml['email']['smtp']['host']
						# yaml parser should provide an integer here
						@options[:smtp_port] ||= yaml['email']['smtp']['port']
					end
				end
			end
			
			if self[:from_mail].to_s.empty?
				WCC.logger.fatal "No sender mail address given! See help."
				exit 1
			end
			
			if self[:show_config]
				Conf.default.merge(@options).each do |k,v|
					puts "  #{k.to_s} => #{self[k]}"
				end
				exit 0
			end
			
			# create cache dir for hash and diff files
			Dir.mkdir(self[:cache_dir]) unless File.directory?(self[:cache_dir])
			
			if(self[:clean])
				WCC.logger.warn "Cleanup hash and diff files"
				Dir.foreach(self[:cache_dir]) do |f|
					File.delete(self.file(f)) if f =~ /^.*\.(md5|site)$/
				end
			end
			
			# read filter.d
			Dir[File.join(self[:filter_dir], '*.rb')].each { |file| require file }
		end
		
		def self.sites
			return @sites unless @sites.nil?
			
			@sites = []
			
			WCC.logger.debug "Load sites from '#{Conf[:conf]}'"
			
			# may be *false* if file is empty
			yaml = YAML.load_file(Conf[:conf])
			
			if not yaml
				WCC.logger.info "No sites loaded"
				return @sites
			end
			
			yaml['sites'].to_a.each do |yaml_site|
				frefs = []
				(yaml_site['filters'] || []).each do |entry|
					if entry.is_a?(Hash)
						# hash containing only one key (filter id),
						# the value is the argument hash
						id = entry.keys[0]
						frefs << FilterRef.new(id, entry[id])
					else entry.is_a?(String)
						frefs << FilterRef.new(entry, {})
					end
				end
				
				if not yaml_site['cookie'].nil?
					cookie = File.open(yaml_site['cookie'], 'r') { |f| f.read }
				end
				
				@sites << Site.new(
					yaml_site['url'], 
					yaml_site['strip_html'] || true,
					yaml_site['emails'].map { |m| MailAddress.new(m) } || [],
					frefs,
					yaml_site['auth'] || {},
					cookie)
			end
			
			WCC.logger.debug @sites.length.to_s + (@sites.length == 1 ? ' site' : ' sites') + " loaded\n" +
				@sites.map { |s| "  #{s.uri.host.to_s}\n    url: #{s.uri.to_s}\n    id: #{s.id}" }.join("\n")
			
			@sites
		end
		
		def self.mailer
			return @mailer unless @mailer.nil?

			# smtp mailer
			if Conf[:mailer] == 'smtp'
				@mailer = SmtpMailer.new(Conf[:smtp_host], Conf[:smtp_port])
			end

			@mailer
		end
		
		def self.file(path = nil) File.join(self[:cache_dir], path) end
		def self.simulate?; self[:simulate] end
		def self.send_mails?; !self[:nomails] end
		def self.[](key); Conf.instance[key] end
	end

	class LogFormatter
		def initialize(use_color = true)
			@color = use_color
		end

		def white;  "\e[1;37m" end
		def cyan;   "\e[1;36m" end
		def magenta;"\e[1;35m" end
		def blue;   "\e[1;34m" end
		def yellow; "\e[1;33m" end
		def green;  "\e[1;32m" end
		def red;    "\e[1;31m" end
		def black;  "\e[1;30m" end
		def rst;    "\e[0m" end

		def call(lvl, time, progname, msg)
			text = "%s: %s" % [lvl, msg.to_s]
			if @color
				return [magenta, text, rst, "\n"].join if lvl == "FATAL"
				return [red, text, rst, "\n"].join if lvl == "ERROR"
				return [yellow, text, rst, "\n"].join if lvl == "WARN"
			end
			[text, "\n"].join
		end
	end

	class Prog
		def self.checkForUpdate(site)
			WCC.logger.info "Requesting '#{site.uri.to_s}'"
			begin
				res = site.fetch
			rescue Timeout::Error => ex
				# don't claim on this
				return false
			rescue => ex
				WCC.logger.error "Cannot connect to #{site.uri.to_s} : #{ex.to_s}"
				return false
			end
			if not res.kind_of?(Net::HTTPOK)
				WCC.logger.error "Site #{site.uri.to_s} returned #{res.code} code, skipping it."
				return false
			end
			
			new_content = res.body
			
			# detect encoding from http header, meta element, default utf-8
			# do not use utf-8 regex because it will fail on non utf-8 pages
			encoding = (res['content-type'].to_s.match(/;\s*charset=([A-Za-z0-9-]*)/i).to_a[1] || 
						new_content.match(/<meta.*charset=([a-zA-Z0-9-]*).*/i).to_a[1]).to_s.downcase || 'utf-8'
			
			WCC.logger.info "Encoding is '#{encoding}'"
			
			# convert to utf-8
			begin
				new_content = Iconv.conv('utf-8', encoding, new_content)
			rescue => ex
				WCC.logger.error "Cannot convert site from '#{encoding}': #{ex.to_s}"
				return false
			end
			
			# strip html
			new_content = new_content.strip_html if site.strip_html?
			new_hash = Digest::MD5.hexdigest(new_content)
			
			WCC.logger.debug "Compare hashes\n  old: #{site.hash.to_s}\n  new: #{new_hash.to_s}"
			return false if new_hash == site.hash
			
			# do not try diff or anything if site was never checked before
			if site.new?
				site.hash, site.content = new_hash, new_content
				
				# set custom diff message
				diff = "Site was first checked so no diff was possible."
			else
				# save old site to tmp file
				old_site_file = Tempfile.new("wcc-#{site.id}-")
				old_site_file.write(site.content)
				old_site_file.close
				
				# calculate labels before updating
				old_label = "OLD (%s)" % File.mtime(Conf.file(site.id + ".md5")).strftime(DIFF_TIME_FMT)
				new_label = "NEW (%s)" % Time.now.strftime(DIFF_TIME_FMT)
			
				site.hash, site.content = new_hash, new_content
				
				# diff between OLD and NEW
				diff = %x[diff -U 1 --label "#{old_label}" --label "#{new_label}" #{old_site_file.path} #{Conf.file(site.id + '.site')}]
			end
			
			# HACK: there *was* an update but no notification is required
			return false if not Filter.accept(diff, site.filters)
			
			# TODO: combine Conf.send_mail? with Filter.accept
			
			data = OpenStruct.new
			data.title = "[#{Conf[:tag]}] #{site.uri.host} changed"
			data.message = "Change at #{site.uri.to_s} - diff follows:\n\n#{diff}"
			
			Conf.mailer.send(data, MailAddress.new(Conf[:from_mail]), site.emails) if Conf.send_mails?
			
			system("logger -t '#{Conf[:tag]}' 'Change at #{site.uri.to_s} (tag #{site.id}) detected'") if Conf[:syslog]
			
			true
		end

		# main
		def self.run!
			WCC.logger = Logger.new(STDOUT)
			
			Conf.sites.each do |site|
				if checkForUpdate(site)
					WCC.logger.warn "#{site.uri.host.to_s} has an update!"
				else
					WCC.logger.info "#{site.uri.host.to_s} is unchanged"
				end
			end
		end
	end
end
