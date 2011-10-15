
WCC::Filters.add 'matches' do |data,args|
	WCC::Filters.debug "regex: #{args['regex']}"
	# args['flags'] is assumed to be a string that might be empty or
	# contains any of the characters 'i','e','m' in any order.
	ropts = []
	if not args['flags'].nil?
		WCC::Filters.debug "flags: #{args['flags']}"
		ropts << Regexp::IGNORECASE if args['options'].include?('i')
		ropts << Regexp::EXTENDED if args['options'].include?('e')
		ropts << Regexp::MULTILINE if args['options'].include?('m')
	end
	WCC::Filters.debug "ropts: #{ropts.inspect}"
	if ropts.empty?
		r = Regexp.new(args['regex'])
	else
		r = Regexp.new(args['regex'], ropts.inject {|acc,x| acc |= x})
	end
	case args['scope']
	when 'diff','change',nil
		md = r.match(data.diff.to_s)
	when 'site','full'
		md = r.match(data.site.content)
	end
	WCC::Filters.debug "match: #{md.inspect}"
	(not md.nil?)
end
