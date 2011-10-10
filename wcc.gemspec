
Gem::Specification.new do |s|
	s.name		= "wcc"
	s.version	= "1.0.0"
	s.summary	= "web change checker"
	s.description = "wcc tracks changes of websites and notifies you by email."
	s.author	= "Christian Nicolai"
	s.email		= "chrnicolai@gmail.com"
	s.license	= "Apache License Version 2.0"
	s.homepage	= "https://github.com/cmur2/wcc"
	s.rubyforge_project = "wcc"
	
	s.files = [
		"assets/conf.yml",
		"assets/filter.d/arg-test.rb",
		"assets/filter.d/test.rb",
		"assets/template.d/mail.alt.erb",
		"assets/template.d/mail-body.html.erb",
		"assets/template.d/mail-body.plain.erb",
		"assets/template.d/mail.plain.erb",
		"bin/wcc",
		"bin/wcc-init",
		"bin/wcc-upgrade",
		"doc/Filters.md",
		"lib/wcc/diff.rb",
		"lib/wcc/filter.rb",
		"lib/wcc/mail.rb",
		"lib/wcc/site.rb",
		"lib/wcc.rb",
		"LICENSE",
		"README.md"
	]
	
	s.extra_rdoc_files = [
		"doc/Filters.md",
		"README.md"
	]
	
	s.require_paths = ["lib"]
	
	s.executables = ["wcc", "wcc-init", "wcc-upgrade"]
	
	s.add_runtime_dependency("htmlentities")
	s.add_runtime_dependency("diff-lcs")
end
