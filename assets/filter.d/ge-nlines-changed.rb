
WCC::Filters.add 'ge-nlines-changed' do |data,args|
	data.diff.nlinesc >= args['num']
end
