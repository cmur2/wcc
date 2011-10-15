
WCC::Filters.add 'and' do |data,args|
	ret = true
	args.each do |id,inner_args|
		if not WCC::Filters.call(data, id, inner_args)
			# short circuit
			ret = false; break
		end
	end
	ret
end
