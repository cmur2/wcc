
module WCC
	class XMPPNotificator
		def initialize(opts)
			@jid = opts
		end
		
		def notify!(data, main, bodies)
			# TODO: implement xmpp
			WCC.logger.info "Assume #{@jid} was notified!"
		end
		
		def self.parse_conf(conf)
			if conf.is_a?(Hash)
				return {
					:xmpp_jid => conf['jid'],
					:xmpp_password => conf['password']
				}
			end
		end
	end
end
