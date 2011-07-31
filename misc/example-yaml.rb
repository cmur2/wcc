#!/usr/bin/ruby -KuW0

require 'yaml'

puts YAML.load_file('conf.yml').inspect
