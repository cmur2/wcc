
module WCC
	class SyslogNotificator

		LEVELS = ['crit', 'emerg', 'alert', 'err', 'warning', 'notice', 'info', 'debug']

		def initialize(opts)
			if LEVELS.include?(opts)	
				@prio = opts
				@enable = true
			else
				@enable = false
				raise ArgumentError, "The given priority '#{opts}' is not known, use one of: #{LEVELS.join(', ')}."
			end
			begin
				# from ruby std lib
				require 'syslog'
			rescue LoadError
				@enable = false
				raise ArgumentError, "Won't log to syslog since your system does NOT support syslog!"
			end
		end
		
		# TODO: ERB template for syslog
		def notify!(data)
			Syslog.open(data.tag, Syslog::LOG_PID | Syslog::LOG_CONS) do |s|
				s.send(@prio.to_sym, "Change at #{data.site.uri.to_s} (tag #{data.site.id}) detected")
			end if @enable
		end
		
		def self.parse_conf(conf); {} end
		
		def self.shut_down; end
	end
end
