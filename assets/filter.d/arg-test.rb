
WCC::Filters.add 'arg-test' do |data,args|
	puts "arg-test:"
	puts "  #arguments = #{args.size}"
	args.each do |arg|
		puts "  - #{arg.inspect}"
	end
	true
end
