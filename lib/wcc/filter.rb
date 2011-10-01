
module WCC
	class FilterRef
		attr_reader :id, :arguments

		def initialize(id, arguments)
			@id = id
			@arguments = arguments
		end
		
		def to_s; @id end
	end

	class Filter
		@@filters = {}
		
		def self.add(id, &block)
			WCC.logger.info "Adding filter '#{id}'"
			@@filters[id] = block
		end
		
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
					WCC.logger.info "Filter #{fref.id} failed!"
					return false
				end
			end
			true
		end
	end
end
