Filter-API
==========

Filters formally are Ruby Proc blocks (mostly contained in small ruby
scripts) referenced by an ID that decide upon a given website diff whether
to notify the user (by email) or not.

These Proc blocks get registered using `Filter.add` with a given ID (a
string, not a :symbol to prevent some problems).

wcc provides an autoloading mechanism that loads all ruby files contained in
a specific directory - the *filter.d* - via `require`.  The filter file
should contain some bootstrap code that may rely only on the *Filter* class
out of wcc:

	Filter.add 'my_custom_id' do |data,arguments|
	    # do your filter magic here
		# and return a boolean
	end

The format of the `data` may change over time, currently it's a string
containing all lines separated by newline of the unified diff (raw from unix
diff).  The arguments are a - possibly empty - hash directly passed in from
the configuration file to parameterize the filter (e.g. ignoring all diffs
shorter than let's say 10 lines).

The output of this filter should be boolean true or false, indicating that
an email should be sent or not.

In the configuration file a filter is referenced like this:

	sites:
	  - url: ...
	    :
	    filters:
	      - test
	      - paramtest: { minLines: 10 }
