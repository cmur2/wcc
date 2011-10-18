
module WCC
	
	# An email address container with internal conversion
	# routines.
	class MailAddress
		def initialize(email)
			email = email.to_s if email.is_a?(MailAddress)
			@email = email.strip
		end
		
		# Extract the 'name' out of an mail address
		#   "Me <me@example.org>" -> "Me"
		#   "me2@example.org" -> "me2"
		#
		# @return [String] name
		def name
			if @email =~ /^[\w\s]+<.+@[^@]+>$/
				@email.gsub(/<.+?>/, '').strip
			else
				@email.split("@")[0...-1].join("@")
			end
		end

		# Return the real mail address
		#   "Me <me@example.org>" -> "me@example.org"
		#   "me2@example.org" -> "me2@example.org"
		#
		# @return [String] mail address
		def address
			if @email =~ /^[\w\s]+<.+@[^@]+>$/
				@email.match(/<([^>]+@[^@>]+)>/)[1]
			else
				@email
			end
		end
		
		def to_s; @email end
	end
	
	class MailNotificator
		@@main = nil
		@@bodies = nil
		
		def initialize(opts)
			@to = MailAddress.new(opts)
		end
		
		# Sends a mail built up from some [ERB] templates to the
		# specified adresses.
		#
		# @param [Object] data used to construct ERB binding
		def notify!(data)
			# from/to addresses
			data.from = Conf[:from_mail]
			data.to = @to
			# generate a boundary that may be used for multipart
			data.boundary = "frontier-#{data.site.id}"
			# generate message
			data.bodies = {}
			# eval all body templates
			self.class.get_bodies.each do |name,template|
				data.bodies[name] = template.result(binding)
			end
			# eval main template
			msg = self.class.get_main.result(binding)
			
			case Conf[:mailer]
			when 'smtp'
				self.class.send_smtp(msg, Conf[:from_mail], @to, Conf[:smtp_host], Conf[:smtp_port])
			when 'fake_file'
				self.class.send_fake_file(msg, Conf[:from_mail], @to)
			end
		end
		
		def self.parse_conf(conf)
			if conf.is_a?(Hash)
				if conf['smtp'].is_a?(Hash)
					from_mail = MailAddress.new(conf['smtp']['from'] || "#{Etc.getlogin}@localhost")
					return {
						:mailer => 'smtp',
						:from_mail => from_mail,
						:smtp_host => conf['smtp']['host'] || 'localhost',
						:smtp_port => conf['smtp']['port'] || 25
					}
				elsif conf['fake_file'].is_a?(Hash)
					return {
						:mailer => 'fake_file',
						:from_mail => conf['fake_file']['from'] || "#{Etc.getlogin}@localhost"
					}
				end
			end
			# default is smtp
			return {
				:mailer => 'smtp',
				:from_mail => MailAddress.new("#{Etc.getlogin}@localhost"),
				:smtp_host => 'localhost',
				:smtp_port => 25
			}
		end
		
		def self.shut_down; end
	
		# This is a specific implementation of an mail deliverer that
		# does plain SMTP to host:port using [Net::SMTP].
		#
		# @param [String] msg the mail
		# @param [MailAddress] from the From: address
		# @param [MailAddress] to array of To: address
		# @param [String] host the SMTP host
		# @param [Integer] port the SMTP port
		def self.send_smtp(msg, from, to, host, port)
			# send message
			Net::SMTP.start(host, port) do |smtp|
				smtp.send_message(msg, from.address, to.address)
			end
		rescue => ex
			WCC.logger.fatal "Cannot send mail via SMTP to #{host}:#{port} : #{ex}"
		end
	
		# This just dumps a mail's contents into an eml file in the current
		# working directory. This should be for TESTING ONLY as it doesn't
		# take care of standards and stuff like that...
		#
		# @param [String] msg the mail
		# @param [MailAddress] from the From: address
		# @param [MailAddress] to array of To: address
		def self.send_fake_file(msg, from, to)
			# dump mail to eml-file
			filename = "#{Time.new.strftime('%Y%m%d-%H%M%S')} #{to.name}.eml"
			File.open(filename, 'w') { |f| f.write(msg) }
		end
		
		# template loading
		def self.get_main
			if @@main.nil?
				@@main = WCC::Prog.load_template('mail.alt.erb')
			end
			@@main
		end
		
		def self.get_bodies
			if @@bodies.nil?
				@@bodies = {
					:plain => WCC::Prog.load_template('mail-body.plain.erb'),
					:html => WCC::Prog.load_template('mail-body.html.erb')
				}
			end
			@@bodies
		end
	end
end
