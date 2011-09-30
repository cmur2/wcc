#!/usr/bin/ruby -KuW0

require 'wcc'

WCC::Filter.add 'paramtest' do |data,arguments|
	puts "Paramtest #arguments: #{arguments.size}"
	true
end
