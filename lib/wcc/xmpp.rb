
module WCC
	class XMPPNotificator
		@@client = nil
		@@template = nil
		
		def initialize(opts)
			@jid = Jabber::JID.new(opts)
		end
		
		def notify!(data)
			# prepare message
			subject = "[#{data.tag}] #{data.site.uri.host} changed"
			body = self.class.get_template.result(binding)
			m = Jabber::Message.new(@jid, body)
			m.type = :normal
			m.subject = subject
			# send it
			c = self.class.get_client
			c.send(m) unless c.nil?
		end
		
		def self.parse_conf(conf)
			if conf.is_a?(Hash)
				if conf['jid'].nil?
					WCC.logger.fatal "Missing jabber ID!"
					return {:xmpp_jid => nil}
				elsif conf['password'].nil?
					WCC.logger.fatal "Missing jabber password!"
				else
					return {
						:xmpp_jid => Jabber::JID.new(conf['jid']),
						:xmpp_password => conf['password']
					}
				end
			end
		end
		
		def self.shut_down
			if not @@client.nil?
				#@@client.send(Jabber::Presence.new.set_type(:unavailable))
				@@client.close
			end
		end
		
		def self.get_client
			if @@client.nil? and not Conf[:xmpp_jid].nil?
				@@client = Jabber::Client.new(Conf[:xmpp_jid])
				@@client.connect
				begin
					@@client.auth(Conf[:xmpp_password])
					@@client.send(Jabber::Presence.new.set_status('At your service every night.'))
				rescue Jabber::ClientAuthenticationFailure => ex
					WCC.logger.fatal "Wrong jabber password for #{Conf[:xmpp_jid]}!"
					@@client.close
					@@client = nil
				end
			end
			@@client
		end
		
		def self.get_template
			if @@template.nil?
				@@template = WCC::Prog.load_template('xmpp-body.plain.erb')
			end
			@@template
		end
	end
end
