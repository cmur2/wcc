
WCC::Filters.add 'or' do |data,args|
	ret = false
	args.each do |id,inner_args|
		if WCC::Filters.call(data, id, inner_args)
			# short circuit
			ret = true; break
		end
	end
	ret
end
