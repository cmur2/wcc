
module WCC
	
	class MailNotificator
		def initialize(opts)
			@to = MailAddress.new(opts)
		end
		
		def notify!(data, main, bodies)
			#WCC.logger.info "Assume #{@to} was notified!"
			
			case Conf[:mailer]
			when 'smtp'
				m = SmtpMailer.new(Conf[:smtp_host], Conf[:smtp_port])
			when 'fake_file'
				m = FakeFileMailer.new
			end
			
			m.send(data, main, bodies, Conf[:from_mail], [@to])
		end
		
		def self.parse_conf(conf)
			if conf.is_a?(Hash)
				if conf['smtp'].is_a?(Hash)
					return {
						:mailer => 'smtp',
						:from_mail => MailAddress.new(conf['smtp']['from']),
						:smtp_host => conf['smtp']['host'],
						:smtp_port => conf['smtp']['port']
					}
				elsif conf['fake_file'].is_a?(Hash)
					return {
						:mailer => 'fake_file',
						:from_mail => conf['fake_file']['from']
					}
				end
			end
		end
	end
	
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

	# SmtpMailer is a specific implementation of an mail deliverer that
	# does plain SMTP to host:port using [Net::SMTP].
	class SmtpMailer
		def initialize(host, port)
			@host = host
			@port = port
			WCC.logger.info "Send mail via SMTP to #{@host}:#{@port}"
		end
		
		# Sends a mail built up from some [ERB] templates to the
		# specified adresses.
		#
		# @param [OpenStruct] data used to construct ERB binding
		# @param [ERB] main the main template
		# @param [Hash] bodies :name, ERB template pairs
		# @param [MailAddress] from the From: address
		# @param [Array] tos array of To: addresses (MailAddress)
		def send(data, main, bodies, from, tos = [])
			# generate a boundary that may be used for multipart
			data.boundary = "frontier-#{data.site.id}"
			# generate messages
			msgs = {}
			tos.each do |to|
				data.bodies = {}
				# eval all body templates
				bodies.each do |name,template|
					data.bodies[name] = template.result(binding)
				end
				# eval main template
				msgs[to] = main.result(binding)
			end
			# send messages
			Net::SMTP.start(@host, @port) do |smtp|
				msgs.each do |to,msg|
					smtp.send_message(msg, from.address, to.address)
				end
			end
		rescue
			WCC.logger.fatal "Cannot send mails via SMTP to #{@host}:#{@port} : #{$!.to_s}"
		end
	end
	
	# This "mailer" just dumps a mail's contents into eml files in the current
	# working directory. This should be for TESTING ONLY as it doesn't
	# take care of standards and stuff like that...
	class FakeFileMailer
		def initialize
			WCC.logger.info "Write mail to eml-files in #{Dir.getwd}"
		end
		
		def send(data, main, bodies, from, tos = [])
			# generate a boundary that may be used for multipart
			data.boundary = "frontier-#{data.site.id}"
			# generate messages
			msgs = {}
			tos.each do |to|
				data.bodies = {}
				# eval all body templates
				bodies.each do |name,template|
					data.bodies[name] = template.result(binding)
				end
				# eval main template
				msgs[to] = main.result(binding)
			end
			# dump mails to eml-files
			i = 0
			msgs.each do |to,msg|
				filename = "#{Time.new.strftime('%Y%m%d-%H%M%S')} to_#{i}.eml"
				File.open(filename, 'w') { |f| f.write(msg) }
				i += 1
			end
		end
	end
end
