
module WCC
	class DiffItem
		attr_accessor :status, :text, :hilite
		
		def initialize(line)
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
				@text = line.substring(1)
			elsif line.start_with?('-')
				@status = :del
				@text = line.substring(1)
			else
				@status = :other
				@text = line
			end
			@text.gsub!(/\n/, '')
			@hilite = nil
		end
		
		def html_hilite_text(css_klass = 'hilite')
			return @text if @hilite.nil?
			
			i = 1
			new_text = ''
			in_span = false
			@text.chars.to_a.each do |c|
				if @hilite.include?(i)
					if not in_span
						new_text += "<span class=\"#{css_klass}\">"
					end
					new_text += c
					in_span = true
				else
					if in_span
						new_text += "</span>"
					end
					new_text += c
					in_span = false
				end
				i += 1
			end
			new_text += "</span>" if in_span
			new_text
		end
		
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
			@di = []
			dstring.lines.each do |line|
				# parse line
				@di << DiffItem.new(line)
			end
			# TODO: compute_hilite, wrong +/- detection
		end
		
		def compute_hilite
			s = rchar
			puts s
			
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
				ranges = Diff::LCS.diff(@di[i].text, @di[i+1].text)
				@di[i].hilite = []
				@di[i+1].hilite = []
				ranges.each do |chg|
					chg.each do |c|
						if c.action == '-' and c.element != ''
							@di[i].hilite << c.position
						end
						if c.action == '+' and c.element != ''
							@di[i+1].hilite << c.position
						end
					end
				end
			end
		end
		
		def rchar
			@di.map { |o| o.rchar }.join
		end
		
		def to_s
			@di.map { |o| o.to_s }.join("\n")
		end
	end
end
