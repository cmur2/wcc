
# NOTE: the percentage may easily go above 100% when there are more
#       changes than the whole site had lines before.

WCC::Filters.add 'rel_changes_of' do |data,args|
	next true if data.diffnil?
	case args['percent_of']
	when 'all_lines',nil
		percent = data.diff.nlinesc.to_f / data.site.content.count("\n").+(1).to_f * 100
	# TODO: extend rel_changes_of filter
#	when 'all_chars','all_characters'
#		percent = ...
#	when 'nonblank_lines'
#		percent = ...
	end
	WCC::Filters.debug "rel_changes_of #{percent} of #{args['percent_of']}"
	next (percent >= args['at_least']) if args.key?('at_least')
	next (percent >  args['more_than']) if args.key?('more_than')
	next (percent <= args['at_most']) if args.key?('at_most')
	next (percent <  args['fewer_then']) if args.key?('fewer_than')
	next (percent == args['exactly']) if args.key?('exactly')
	next (percent != args['not_quite']) if args.key('not_quite')
	true
end
