
module WCC
	class MailAddress
		def initialize(email)
			email = email.to_s if email.is_a?(MailAddress)
			@email = email.strip
		end
		
		def name
			if @email =~ /^[\w\s]+<.+@[^@]+>$/
				@email.gsub(/<.+?>/, '').strip
			else
				@email.split("@")[0...-1].join("@")
			end
		end

		def address
			if @email =~ /^[\w\s]+<.+@[^@]+>$/
				@email.match(/<([^>]+@[^@>]+)>/)[1]
			else
				@email
			end
		end
		
		def to_s; @email end
	end

	class Mail
		attr_reader :title, :message
		
		def initialize(title, message, options = {})
			@title = title
			@message = message
			@options = {:from => MailAddress.new(Conf[:from_mail])}
			@options[:from] = MailAddress.new(options[:from]) unless options[:from].nil?
		end
		
		def send(tos = [])
			Conf.mailer.send(self, @options[:from], tos)
		end
	end

	class SmtpMailer
		def initialize(host, port)
			@host = host
			@port = port
		end
		
		def send(mail, from, to = [])
			Net::SMTP.start(@host, @port) do |smtp|
				to.each do |toaddr|
					msg  = "From: #{from.name} <#{from.address}>\n"
					msg += "To: #{toaddr}\n"
					msg += "Subject: #{mail.title.gsub(/\s+/, ' ')}\n"
					msg += "Content-Type: text/plain; charset=\"utf-8\"\n"
					msg += "Content-Transfer-Encoding: base64\n"
					msg += "\n"
					msg += Base64.encode64(mail.message)
					
					smtp.send_message(msg, from.address, toaddr.address)
				end
			end
		rescue
			WCC.logger.fatal "Cannot send mails at #{@host}:#{@port} : #{$!.to_s}"
		end
	end
end
