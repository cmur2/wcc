
module WCC
	# TODO: Handle tabs/trailing whitespace in output

	class DiffItem
		attr_reader :status, :text
		attr_accessor :hilite
		
		def initialize(line)
			# parse line
			if line.start_with?('+++')
				@status = :new
				@text = line.substring(3)
			elsif line.start_with?('---')
				@status = :old
				@text = line.substring(3)
			elsif line.start_with?('@@')
				@status = :range
				@text = line.substring(2)
			elsif line.start_with?('+')
				@status = :ins
				@text = line.substring(1).rstrip
			elsif line.start_with?('-')
				@status = :del
				@text = line.substring(1).rstrip
			else
				@status = :other
				@text = line.rstrip
				@text = ' ' if @text.empty?
			end
			@text.gsub!(/\n/, '')
			@hilite = nil
		end
		
		def html_hilite_text(css_klass = 'hilite')
			return @text if @hilite.nil?
			
			i = 0
			new_text = ''
			in_span = false
			@text.chars.to_a.each do |c|
				if @hilite.include?(i)
					if not in_span
						new_text += "<span class=\"#{css_klass}\">"
						in_span = true
					end
					new_text += (c == ' ' ? '&nbsp;' : c)
				else
					if in_span
						new_text += "</span>"
						in_span = false
					end
					new_text += c
				end
				i += 1
			end
			new_text += "</span>" if in_span
			new_text
		end
		
		# Returns a representing character for the kind of this diff item.
		# @return [String] single rep char
		def rchar
			case status
			when :new
				'N'
			when :old
				'O'
			when :range
				'@'
			when :ins
				'i'
			when :del
				'd'
			when :other
				'_'
			end
		end
		
		# Returns an unified diff line without trailing newline.
		# @return [String] unified diff line
		def to_s
			case status
			when :new
				'+++'+text
			when :old
				'---'+text
			when :range
				'@@'+text
			when :ins
				'+'+text
			when :del
				'-'+text
			when :other
				text
			end
		end
	end
	
	class Differ
		attr_reader :di
		
		def initialize(dstring)
			@di = dstring.lines.map { |line| DiffItem.new(line) }
			compute_hilite
		end
		
		def compute_hilite
			# get representional string for the whole diff
			s = rchar
			#puts s
			mds = []
			md = s.match(/(@|_)di(@|_)/)
			while not md.nil?
				mds << md
				s = s.substring(md.begin(2)+1)
				md = s.match(/(@|_)di(@|_)/)
			end
			
			offset = 0
			mds.each do |md|
				i = offset+md.begin(1)+1
				offset = md.begin(2)+1
				# found a single insertion/deletion pair
				InLineDiffer.new(@di[i], @di[i+1]).compute_hilite
			end
		end
		
		def nhunks
			@di.inject(0) { |sum,o| sum += (o.status == :range ? 1 : 0) }
		end
		
		def ninsertions
			@di.inject(0) { |sum,o| sum += (o.status == :ins ? 1 : 0) }
		end
		
		def ndeletions
			@di.inject(0) { |sum,o| sum += (o.status == :del ? 1 : 0) }
		end
		
		def nlinesc
			ninsertions + ndeletions
		end
		
		def ncharsc
			@di.inject(0) { |sum,o| sum += (o.hilite.nil? ? 0 : o.hilite.nitems) }
		end
		
		def rchar
			@di.map { |o| o.rchar }.join
		end
		
		def to_s
			@di.map { |o| o.to_s }.join("\n")
		end
	end
	
	# Calculates hilite based on per char side-by-side diff for two DiffItems.
	class InLineDiffer
		def initialize(a, b)
			@a = a
			@b = b
			@a.hilite = []
			@b.hilite = []
		end
		
		def compute_hilite
			#puts @a.text.chars.to_a.inspect
			#puts @b.text.chars.to_a.inspect
			# HACK: Diff::LCS with plain strings fails on Ruby 1.8 even with -Ku flag but not: <string>.chars.to_a
			Diff::LCS.traverse_balanced(@a.text.chars.to_a, @b.text.chars.to_a, self)
		end
		
		def match(e)
			# don't care
		end
		
		def discard_a(e)
			@a.hilite << e.old_position if not @a.hilite.include?(e.old_position)
		end
		
		def discard_b(e)
			@b.hilite << e.new_position if not @b.hilite.include?(e.new_position)
		end
		
		def change(e)
			@a.hilite << e.old_position if not @a.hilite.include?(e.old_position)
			@b.hilite << e.new_position if not @b.hilite.include?(e.new_position)
		end
	end
end
