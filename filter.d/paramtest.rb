#!/usr/bin/ruby -KuW0

Filter.add 'paramtest' do |data,arguments|
	puts "Paramtest #arguments: #{arguments.size}"
	true
end
