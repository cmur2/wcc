
WCC::Filters.add 'changes_of' do |data,args|
	next true if data.diff.nil?
	case args['t'] || args['type']
	when 'line','lines',nil
		cmp_val = data.diff.nlinesc
	when 'char','chars'
		cmp_val = data.diff.ncharsc
	when 'ins','insertions'
		cmp_val = data.diff.ninsertions
	when 'del','deletions'
		cmp_val = data.diff.ndeletions
	when 'hunk','hunks'
		cmp_val = data.diff.nhunks
	end
	WCC::Filters.debug "changes_of #{cmp_val} #{args['t'] || args['type']}"
	next (cmp_val >= args['at_least']) if args.key?('at_least')
	next (cmp_val >  args['more_than']) if args.key?('more_than')
	next (cmp_val <= args['at_most']) if args.key?('at_most')
	next (cmp_val <  args['fewer_then']) if args.key?('fewer_than')
	next (cmp_val == args['exactly']) if args.key?('exactly')
	next (cmp_val != args['not_quite']) if args.key('not_quite')
	true
end
