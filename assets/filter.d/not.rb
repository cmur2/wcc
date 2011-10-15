
WCC::Filters.add 'not' do |data,args|
	id = args.keys.first
	(not WCC::Filters.call(data, id, args[id]))
end
