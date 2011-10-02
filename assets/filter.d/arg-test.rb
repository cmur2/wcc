
WCC::Filter.add 'arg-test' do |data,arguments|
	puts "arg-test:"
	puts "  #arguments = #{arguments.size}"
	arguments.each do |arg|
		puts "  - #{arg.inspect}"
	end
	true
end
