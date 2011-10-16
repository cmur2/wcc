
require 'base64'
require 'digest/md5'
require 'erb'
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
require 'diff-lcs'
require 'htmlentities'

# wcc
require 'wcc/diff'
require 'wcc/filter'
require 'wcc/mail'
require 'wcc/site'
require 'wcc/syslog'
require 'wcc/xmpp'

class String
	# Remove all HTML tags with at least one character name and
	# decode all HTML entities into utf-8 characters.
	#
	# @return [String] stripped string
	def strip_html
		HTMLEntities.new.decode(self.gsub(/<[^>]+>/, ' '))
	end
	
	# Returns all characters from the i-th to the end.
	# 
	# @param [Integer] i offset to start substring
	# @return [String] slice(i...length)
	def substring(i)
		slice(i...length)
	end
end

module WCC

	VERSION = "1.3.0"

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
		
		attr_reader :recipients
		
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
				:filter_dir => './filter.d',
				:template_dir => './template.d',
#				:mailer => 'smtp',
#				:smtp_host => 'localhost',
#				:smtp_port => 25
			}
		end
		
		def initialize
			@options = {}
			
			OptionParser.new do |opts|
				opts.banner =  "Usage: ruby wcc.rb [options] [config-yaml-file]"
				opts.banner += "\nOptions:\n"
				opts.on('-v', '--verbose', 'Output more information') do self[:verbose] = true end
				opts.on('-d', '--debug', 'Enable debug mode') do self[:debug] = true end
				opts.on('--cache-dir DIR', 'Save hash and diff files to DIR') do |dir| self[:cache_dir] = dir end
				opts.on('-s', '--simulate', 'Check for update but do not save hash or diff files') do self[:simulate] = true end
				opts.on('--clean', 'Remove all saved hash and diff files') do self[:clean] = true end
				opts.on('-t', '--tag TAG', 'Set TAG used in output') do |t| self[:tag] = t end
				opts.on('-n', '--no-mails', 'Do not send any emails') do self[:nomails] = true end
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
			WCC.logger.info "web change checker (aka wcc) #{WCC::VERSION}"
			WCC.logger.info "Licensed under Apache License Version 2.0"
			
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
				@options[:cache_dir] ||= yaml['cache_dir']
				@options[:tag] ||= yaml['tag']
				@options[:filter_dir] ||= yaml['filterd']
				@options[:template_dir] ||= yaml['templated']
				
				MailNotificator.parse_conf(yaml['email']).each do |k,v| @options[k] ||= v end
				XMPPNotificator.parse_conf(yaml['jabber']).each do |k,v| @options[k] ||= v end
				SyslogNotificator.parse_conf(yaml['syslog']).each do |k,v| @options[k] ||= v end
			end
			
#			TODO: if self[:from_mail].to_s.empty?
#				WCC.logger.fatal "No sender mail address given! See help."
#				exit 1
#			end
			
			if self[:show_config]
				Conf.default.merge(@options).each do |k,v|
					puts "  #{k.to_s} => #{self[k]}"
				end
				exit 0
			end
			
			@recipients = {}
			WCC.logger.debug "Load recipients from '#{self[:conf]}'"
			# may be *false* if file is empty
			yaml = YAML.load_file(self[:conf])
			if not yaml
				WCC.logger.info "No recipients loaded"
			else
				yaml['recipients'].to_a.each do |yaml_rec|
					name = yaml_rec.keys.first
					rec = []
					yaml_rec[name].to_a.each do |yaml_way|
						# TODO: find options and pass them to every notificator
						rec << XMPPNotificator.new(yaml_way['jabber']) if yaml_way.key?('jabber')
						rec << MailNotificator.new(yaml_way['email']) if yaml_way.key?('email')
					end
					@recipients[name] = rec
				end
			end
			
			# attach --no-mails filter
			WCC::Filters.add '--no-mails' do |data|
				!self[:nomails]
			end
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
				# query --no-mails filter for every site
				frefs = [FilterRef.new('--no-mails')]
				(yaml_site['filters'] || []).each do |entry|
					if entry.is_a?(Hash)
						# hash containing only one key (filter id),
						# the value is the argument hash
						id = entry.keys[0]
						frefs << FilterRef.new(id, entry[id])
					else entry.is_a?(String)
						frefs << FilterRef.new(entry)
					end
				end
				
				if not yaml_site['cookie'].nil?
					cookie = File.open(yaml_site['cookie'], 'r') { |f| f.read }
				end
				

				@sites << Site.new(
					yaml_site['url'], 
					yaml_site['strip_html'] || true,
					yaml_site['notify'] || [],
					frefs,
					yaml_site['auth'] || {},
					cookie,
					yaml_site['check_interval'] || 5)
			end
			
			WCC.logger.debug @sites.length.to_s + (@sites.length == 1 ? ' site' : ' sites') + " loaded\n" +
				@sites.map { |s| "  #{s.uri.host.to_s}\n    url: #{s.uri.to_s}\n    id: #{s.id}" }.join("\n")
			
			@sites
		end
		
		def self.recipients
			return Conf.instance.recipients
		end
		
		def self.file(path = nil) File.join(self[:cache_dir], path) end
		def self.simulate?; self[:simulate] end
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
				
				# signal that no diff was posible
				diff = nil
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
			
			# construct the data made available to filters and templates
			data = OpenStruct.new
			data.site = site
			data.diff = diff.nil? ? nil : WCC::Differ.new(diff)
			data.tag = Conf[:tag]
			
			# HACK: there *was* an update but no notification is required
			return false if not Filters.accept(data, site.filters)
			
			site.notify.each do |name|
				rec = Conf.recipients[name]
				if rec.nil?
					WCC.logger.error "Could not notify recipient #{name} - not found!"
				else
					rec.each do |way| way.notify!(data, @@mail_plain, @@mail_bodies) end
				end
			end
			
			true
		end

		# main
		def self.run!
			# first use of Conf initializes it
			WCC.logger = Logger.new(STDOUT)
			
			# make sure logger is correctly configured
			Conf.instance
			
			# create cache dir for hash and diff files
			Dir.mkdir(Conf[:cache_dir]) unless File.directory?(Conf[:cache_dir])
			
			if(Conf[:clean])
				WCC.logger.warn "Cleanup hash and diff files"
				Dir.foreach(Conf[:cache_dir]) do |f|
					File.delete(Conf.file(f)) if f =~ /^.*\.(md5|site)$/
				end
			end
			
			# read filter.d
			Dir[File.join(Conf[:filter_dir], '*.rb')].each { |file| require file }
			
			# timestamps
			cache_file = Conf.file('cache.yml')
			if File.exists?(cache_file)
				WCC.logger.debug "Load timestamps from '#{cache_file}'"

				# may be *false* if file is empty
				yaml = YAML.load_file(cache_file)

				if not yaml
					WCC.logger.info "No timestamps loaded"
				else
					@@timestamps = yaml['timestamps']
				end
			else
				@@timestamps = {}
			end
			
			# templates
			@@mail_plain = load_template('mail.alt.erb')
			@@mail_bodies = {
				:plain => load_template('mail-body.plain.erb'),
				:html => load_template('mail-body.html.erb')
			}
			
			Conf.sites.each do |site|
				ts_old = get_timestamp(site)
				ts_new = Time.now.to_i
				if (ts_new-ts_old) < site.check_interval*60
					ts_diff = (ts_new-ts_old)/60
					WCC.logger.info "Skipping check for #{site.uri.host.to_s} due to check #{ts_diff} minute#{ts_diff == 1 ? '' : 's'} ago."
					next
				end
				if checkForUpdate(site)
					WCC.logger.warn "#{site.uri.host.to_s} has an update!"
				else
					WCC.logger.info "#{site.uri.host.to_s} is unchanged"
				end
				update_timestamp(site, ts_new)
			end
			
			# save timestamps
			File.open(cache_file, 'w+') do |f| YAML.dump({"timestamps" => @@timestamps}, f) end
		end
		
		private
		
		def self.load_template(name)
			t_path = File.join(Conf[:template_dir], name)
			t = File.open(t_path, 'r') { |f| f.read }
			# <> omit newline for lines starting with <% and ending in %>
			ERB.new(t, 0, "<>")
		end
		
		def self.get_timestamp(site)
			@@timestamps[site.uri.to_s] || 0
		end
		
		def self.update_timestamp(site, t)
			@@timestamps[site.uri.to_s] = t
		end
	end
end
