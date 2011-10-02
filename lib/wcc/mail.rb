
module WCC
	# An email address container with internal conversion
	# routines.
	class MailAddress
		def initialize(email)
			email = email.to_s if email.is_a?(MailAddress)
			@email = email.strip
		end
		
		# Extract the 'name' out of an mail address:
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

		# Return the real mail address:
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
		
		def send(data, from, tos = [])
			Net::SMTP.start(@host, @port) do |smtp|
				tos.each do |to|
					msg  = "From: #{from.name} <#{from.address}>\n"
					msg += "To: #{to}\n"
					msg += "Subject: #{data.title.gsub(/\s+/, ' ')}\n"
					msg += "Content-Type: text/plain; charset=\"utf-8\"\n"
					msg += "Content-Transfer-Encoding: base64\n"
					msg += "\n"
					msg += Base64.encode64(data.message)
					
					smtp.send_message(msg, from.address, to.address)
				end
			end
		rescue
			WCC.logger.fatal "Cannot send mails via SMTP to #{@host}:#{@port} : #{$!.to_s}"
		end
	end
end
