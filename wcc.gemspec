
Gem::Specification.new do |s|
	s.name		= "wcc"
	s.version	= "0.0.4"
	s.summary	= "web change checker"
	s.description = "wcc tracks changes of websites and notifies you by email."
	s.author	= "Christian Nicolai"
	s.email		= "chrnicolai@gmail.com"
	#s.license	= ""
	s.homepage	= "https://github.com/cmur2/wcc"
	s.rubyforge_project = "wcc"
	
	s.files = [
		"bin/wcc",
		"doc/Filters.md",
		"lib/wcc/filter.rb",
		"lib/wcc/mail.rb",
		"lib/wcc/site.rb",
		"lib/wcc.rb",
		"README.md"
	]
	
	s.require_paths = ["lib"]
	
	s.executables = ["wcc"]
	
	s.add_runtime_dependency("htmlentities")
end
