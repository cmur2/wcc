
module WCC
	class SyslogNotificator
		def initialize
		end
		
		def notify!(data, main, bodies)
			system("logger -t '#{data.tag}' 'Change at #{data.site.uri.to_s} (tag #{data.site.id}) detected'")
		end
		
		def self.parse_conf(conf); {} end
	end
end
