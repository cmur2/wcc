
module WCC
	class FilterRef
		attr_reader :id, :arguments

		def initialize(id, arguments = {})
			@id = id
			@arguments = arguments
		end
		
		def to_s; @id end
	end

	class Filters
		@@filters = {}
		
		# API method - register a filters code block under given ID.
		# Should be called by filters the following way:
		#
		#   WCC::Filters.add 'filter-name' { block }
		#
		# @param [String] id the "name" of the filter
		# @param [Proc] block a block of code returning true (Accept)
		#                     or false (Decline) as the filters result
		def self.add(id, &block)
			WCC.logger.info "Adding filter '#{id}'"
			@@filters[id] = block
		end
		
		# API method - invoke the specfied filter and give it's result.
		#
		# @param [Object] data arbitrary data the filter might use
		# @param [String] id the "name" of the filter
		# @param [Hash] args the arguments of the filter
		# @return [Boolean] true if filter returned true, false otherwise
		def self.call(data, id, args = {})
			block = @@filters[id]
			if block.nil?
				raise "Call to requested filter '#{id}' failed - filter not found!"
			end
			block.call(data, args)
		end
		
		# Called by wcc check routine to evaluate all filters
		# and produce and'ed result of their boolean returns.
		#
		# @param [Object] data arbitrary data the filters might use
		# @param [Array] filters list of FilterRefs with the IDs of the
		#                        filters to be executed
		# @return [Boolean] true if all filters returned true, false otherwise
		def self.accept(data, filters)
			return true if filters.nil?
			
			WCC.logger.info "Testing with filters: #{filters.join(', ')}"
			filters.each do |fref|
				block = @@filters[fref.id]
				if block.nil?
					WCC.logger.error "Requested filter '#{fref.id}' not found, skipping it."
					next
				end
				if not block.call(data, fref.arguments)
					WCC.logger.info "Filter '#{fref.id}' failed!"
					return false
				end
			end
			true
		end
	end
end
