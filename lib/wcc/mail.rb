
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

	# SmtpMailer is a specific implementation of an mail deliverer that
	# does plain SMTP to host:port using [Net::SMTP].
	class SmtpMailer
		def initialize(host, port)
			@host = host
			@port = port
		end
		
		def send(data, main_t, body_t, from, tos = [])
			Net::SMTP.start(@host, @port) do |smtp|
				tos.each do |to|
					# eval body_t
					data.body = body_t.result(binding)
					# eval main_t
					msg = main_t.result(binding)
					smtp.send_message(msg, from.address, to.address)
				end
			end
		rescue
			WCC.logger.fatal "Cannot send mails via SMTP to #{@host}:#{@port} : #{$!.to_s}"
		end
	end
end
