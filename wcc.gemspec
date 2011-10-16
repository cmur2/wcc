
$:.push File.expand_path("../lib", __FILE__)

require 'wcc/version'

Gem::Specification.new do |s|
	s.name		= "wcc"
	s.version	= WCC::VERSION
	s.summary	= "web change checker"
	s.description = "wcc tracks changes of websites and notifies you by email."
	s.author	= "Christian Nicolai"
	s.email		= "chrnicolai@gmail.com"
	s.license	= "Apache License Version 2.0"
	s.homepage	= "https://github.com/cmur2/wcc"
	s.rubyforge_project = "wcc"
	
	s.files = [
		"assets/conf.yml",
		"assets/filter.d/and.rb",
		"assets/filter.d/arg-test.rb",
		"assets/filter.d/changes_of.rb",
		"assets/filter.d/matches.rb",
		"assets/filter.d/not.rb",
		"assets/filter.d/or.rb",
		"assets/filter.d/rel_changes_of.rb",
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
		"lib/wcc/syslog.rb",
		"lib/wcc/version.rb",
		"lib/wcc/xmpp.rb",
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
	
	s.post_install_message = "NOTE: Remember to ´wcc-upgrade´ your conf.yml directory!"
	
	s.add_runtime_dependency "htmlentities", '~> 4.3'
	s.add_runtime_dependency "diff-lcs", '~> 1.1'
	s.add_runtime_dependency "xmpp4r"
end
